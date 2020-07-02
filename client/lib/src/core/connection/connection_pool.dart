import 'dart:io';

import 'package:http2/http2.dart';
import 'package:ip/ip.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/address.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/connection/connection_state.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_options.dart';

/// Manages reuse of HTTP and HTTP/2 connections for reduced network latency.
class ConnectionPool implements Closeable {
  final _connectionStates = <String, ConnectionState>{};
  Duration _idleTimeout;
  var _isClosed = false;

  ConnectionPool({
    Duration idleTimeout,
  })  : assert(idleTimeout == null ||
            (!idleTimeout.isNegative && idleTimeout.inSeconds > 0)),
        _idleTimeout = idleTimeout ?? defaultIdleTimeout;

  static const defaultIdleTimeout = Duration(minutes: 5);

  /// Returns total number of connections in the pool.
  int get connectionCount => _connectionStates.length;

  /// Returns the number of idle connections in the pool.
  int get idleConnectionCount =>
      _connectionStates.values.where((c) => c.isIdle).length;

  bool get isEmpty => connectionCount == 0;

  bool get isNotEmpty => !isEmpty;

  Duration get idleTimeout => _idleTimeout;

  set idleTimeout(Duration value) {
    _idleTimeout = value;

    for (final state in _connectionStates.values) {
      state.timeout = _idleTimeout;
    }
  }

  String _key(Request request) {
    final options = request.options;
    final uri = request.uri;
    final port = uri.effectivePort;
    final version = options.http2 ? '2' : '1';
    return Connection.makeKey(version, uri.scheme, uri.host, port);
  }

  Future<ConnectionState> get(
    Restio restio,
    Request request,
  ) async {
    if (isClosed) {
      throw const RestioException('ConnectionPool is closed');
    }

    final options = request.options;
    final uri = request.uri;
    final key = _key(request);
    final proxy = options.proxy != null &&
            (options.proxy.http && request.uri.scheme == 'http' ||
                options.proxy.https && request.uri.scheme == 'https')
        ? options.proxy
        : null;

    if (_connectionStates.containsKey(key)) {
      final state = _connectionStates[key];

      if (!state.isClosed) {
        return state;
      }
    }

    // DNS.
    IpAddress ip;

    // Verificar se não é um IP.
    // Busca o real endereço (IP) do host através de um DNS.
    if (options.dns != null && !isIp(uri.host)) {
      final addresses = await options.dns.lookup(uri.host);

      if (addresses != null && addresses.isNotEmpty) {
        ip = addresses[0];
      }
    }

    final address = Address(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.effectivePort,
      proxy: proxy,
      ip: ip,
    );

    final client = await makeClient(restio, options, address);

    final connection = await makeConnection(
      options,
      client,
      address,
    );

    final state = await makeState(key, connection, () {
      if (options.persistentConnection) {
        _connectionStates.remove(key);
      }
    });

    if (options.persistentConnection) {
      _connectionStates[key] = state;
    }

    return state;
  }

  @protected
  Future makeClient(
    Restio restio,
    RequestOptions options,
    Address address,
  ) {
    if (options.http2) {
      return makeHttp2Client(restio, options, address);
    } else {
      return makeHttpClient(restio, options, address);
    }
  }

  // HTTP/HTTPS.

  @protected
  SecurityContext createContext(
    Restio restio,
    RequestOptions options,
    Address address,
  ) {
    final context =
        SecurityContext(withTrustedRoots: restio.withTrustedRoots ?? true);

    // Busca o certificado.
    final certificate = options.certificate ??
        restio.certificates?.firstWhere(
          (certificate) {
            return certificate.matches(
              address.host,
              address.port,
            );
          },
          orElse: () => null,
        );

    if (certificate != null) {
      final chainBytes = certificate.certificate;
      final keyBytes = certificate.privateKey;
      final password = certificate.password;

      if (chainBytes != null) {
        context.useCertificateChainBytes(
          chainBytes,
          password: password,
        );
      }

      if (keyBytes != null) {
        context.usePrivateKeyBytes(
          keyBytes,
          password: password,
        );
      }
    }

    return context;
  }

  @protected
  Future<HttpClient> makeHttpClient(
    Restio restio,
    RequestOptions options,
    Address address,
  ) async {
    final context = options.context ?? createContext(restio, options, address);
    final httpClient = HttpClient(context: context);

    // Proxy.
    if (address.proxy != null) {
      httpClient.findProxy = (uri) {
        return 'PROXY ${address.proxy.host}:${address.proxy.port};';
      };
    }

    // TODO: CertificatePinners: https://github.com/dart-lang/sdk/issues/35981.

    httpClient.badCertificateCallback = (cert, host, port) {
      return !options.verifySSLCertificate ||
          (restio.onBadCertificate?.call(cert, host, port) ?? false);
    };

    return httpClient;
  }

  // HTTP2.

  @protected
  Future<List> makeHttp2Client(
    Restio restio,
    RequestOptions options,
    Address address,
  ) async {
    Socket socket;

    if (options.connectTimeout != null && !options.connectTimeout.isNegative) {
      socket = await createSocket(restio, options, address)
          .timeout(options.connectTimeout);
    } else {
      socket = await createSocket(restio, options, address);
    }

    final settings =
        ClientSettings(allowServerPushes: options.allowServerPushes);

    return [
      socket,
      ClientTransportConnection.viaSocket(socket, settings: settings)
    ];
  }

  @protected
  Future<Socket> createSocket(
    Restio restio,
    RequestOptions options,
    Address address,
  ) {
    return address.scheme == 'https'
        ? SecureSocket.connect(
            address.host,
            address.port,
            context: SecurityContext(withTrustedRoots: restio.withTrustedRoots),
            supportedProtocols: const [
              'h2-14',
              'h2-15',
              'h2-16',
              'h2-17',
              'h2'
            ],
            onBadCertificate: (cert) {
              return !options.verifySSLCertificate ||
                  (restio?.onBadCertificate?.call(
                        cert,
                        address.host,
                        address.port,
                      ) ??
                      false);
            },
          )
        : Socket.connect(address.host, address.port);
  }

  @protected
  Future<ConnectionState> makeState(
    String key,
    Connection connection,
    void Function() onTimeout,
  ) async {
    final state =
        ConnectionState(connection, idleTimeout, onTimeout: onTimeout);

    if (connection is _Http2Connection) {
      final transport = connection.transport;

      transport.onActiveStateChanged = (active) {
        if (!state.isClosed) {
          if (active) {
            state.stop();
          } else {
            state.start();
          }
        }
      };
    }

    return state;
  }

  @protected
  Future<Connection> makeConnection(
    RequestOptions options,
    dynamic client,
    Address address,
  ) async {
    if (options.http2) {
      return _Http2Connection(
        address: address,
        socket: client[0],
        transport: client[1],
      );
    } else {
      return _HttpConnection(
        address: address,
        client: client,
      );
    }
  }

  /// Closes and removes all connections in the pool.
  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    for (final state in _connectionStates.values) {
      await state.close();
    }

    _connectionStates.clear();

    _isClosed = true;
  }

  @override
  bool get isClosed => _isClosed;
}

// ignore: must_be_immutable
class _HttpConnection extends Connection {
  final HttpClient client;
  var _isClosed = false;

  _HttpConnection({
    @required Address address,
    @required this.client,
  }) : super(
          http2: false,
          address: address,
          data: [client],
        );

  @override
  Future<void> close() async {
    if (!isClosed) {
      _isClosed = true;
      client.close();
    }
  }

  @override
  Future<void> cancel() async {
    if (!isClosed) {
      _isClosed = true;
      client.close(force: true);
    }
  }

  @override
  bool get isClosed => _isClosed;
}

class _Http2Connection extends Connection {
  final Socket socket;
  final ClientTransportConnection transport;

  _Http2Connection({
    @required Address address,
    @required this.socket,
    @required this.transport,
  }) : super(
          http2: true,
          address: address,
          data: [socket, transport],
        );

  @override
  Future<void> close() async {
    if (!isClosed) {
      await transport.finish();
    }
  }

  @override
  Future<void> cancel() async {
    if (!isClosed) {
      await transport.terminate();
    }
  }

  @override
  bool get isClosed => !transport.isOpen;
}
