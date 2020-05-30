import 'dart:io';

import 'package:http2/http2.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/connection/connection_state.dart';
import 'package:restio/src/core/request/request.dart';

/// Manages reuse of HTTP and HTTP/2 connections for reduced network latency.
class ConnectionPool implements Closeable {
  final Duration idleTimeout;
  final _connectionStates = <String, ConnectionState>{};
  var _closed = false;

  ConnectionPool({
    Duration idleTimeout,
  }) : idleTimeout = idleTimeout ?? defaultIdleTimeout {
    if (this.idleTimeout.isNegative || this.idleTimeout.inSeconds == 0) {
      throw ArgumentError.value(this.idleTimeout, 'idleTimeout');
    }
  }

  static const defaultIdleTimeout = Duration(minutes: 5);

  int get length => _connectionStates.length;

  Future<ConnectionState> get(
    Restio restio,
    Request request, [
    String ip,
  ]) async {
    final uri = request.uri;
    final port = uri.effectivePort;
    final version = request.options.http2 ? '2' : '1';
    final key = Connection.makeKey(version, uri.scheme, uri.host, port, ip);

    if (_connectionStates.containsKey(key)) {
      final state = _connectionStates[key];

      if (!state.isClosed) {
        return state;
      }
    }

    final client = await makeClient(restio, request);

    final connection = await makeConnection(
      request,
      client,
      ip,
    );

    _connectionStates[key] = await makeState(key, connection, () {
      _connectionStates.remove(key);
    });

    return _connectionStates[key];
  }

  Future makeClient(
    Restio restio,
    Request request,
  ) {
    if (request.options.http2) {
      return _makeHttp2Client(restio, request);
    } else {
      return _makeHttpClient(restio, request);
    }
  }

  // HTTP/HTTPS.

  Future<HttpClient> _makeHttpClient(
    Restio restio,
    Request request,
  ) async {
    final options = request.options;

    final context =
        SecurityContext(withTrustedRoots: restio.withTrustedRoots ?? true);

    // Busca o certificado.
    final certificate = options.certificate ??
        restio.certificates?.firstWhere(
          (certificate) {
            return certificate.matches(
              request.uri.host,
              request.uri.effectivePort,
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

    final httpClient = HttpClient(context: context);

    // TODO: CertificatePinners: https://github.com/dart-lang/sdk/issues/35981.

    httpClient.badCertificateCallback = (cert, host, port) {
      return !options.verifySSLCertificate ||
          (restio.onBadCertificate?.call(cert, host, port) ?? false);
    };

    return httpClient;
  }

  // HTTP2.

  Future<List> _makeHttp2Client(
    Restio restio,
    Request request,
  ) async {
    final options = request.options;

    Socket socket;

    if (options.connectTimeout != null && !options.connectTimeout.isNegative) {
      socket =
          await _createSocket(restio, request).timeout(options.connectTimeout);
    } else {
      socket = await _createSocket(restio, request);
    }

    final settings =
        ClientSettings(allowServerPushes: options.allowServerPushes);

    return [
      socket,
      ClientTransportConnection.viaSocket(socket, settings: settings)
    ];
  }

  Future<Socket> _createSocket(
    Restio restio,
    Request request,
  ) {
    final options = request.options;
    final port = request.uri.effectivePort;

    return request.uri.scheme == 'https'
        ? SecureSocket.connect(
            request.uri.host,
            port,
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
                        request.uri.host,
                        port,
                      ) ??
                      false);
            },
          )
        : Socket.connect(request.uri.host, port);
  }

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
        if (active) {
          state.stop();
        } else {
          state.start();
        }
      };
    }

    return state;
  }

  Future<Connection> makeConnection(
    Request request,
    dynamic client, [
    String ip,
  ]) async {
    final uri = request.uri;

    if (request.options.http2) {
      final uri = request.uri;

      return _Http2Connection(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.effectivePort,
        ip: ip,
        socket: client[0],
        transport: client[1],
      );
    } else {
      return _HttpConnection(
        scheme: uri.scheme,
        host: uri.host,
        port: uri.effectivePort,
        ip: ip,
        client: client,
      );
    }
  }

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    _closed = true;

    try {
      for (final state in _connectionStates.values) {
        await state.close();
      }
    } finally {
      _connectionStates.clear();
    }
  }

  @override
  bool get isClosed => _closed;
}

// ignore: must_be_immutable
class _HttpConnection extends Connection {
  final HttpClient client;
  var _isClosed = false;

  _HttpConnection({
    @required String scheme,
    @required String host,
    @required int port,
    String ip,
    @required this.client,
  }) : super(
          http2: false,
          scheme: scheme,
          host: host,
          port: port,
          ip: ip,
          data: {'client': client},
        );

  @override
  Future<void> close() async {
    if (!isClosed) {
      _isClosed = true;
      client.close();
    }
  }

  @override
  bool get isClosed => _isClosed;
}

class _Http2Connection extends Connection {
  final Socket socket;
  final ClientTransportConnection transport;

  _Http2Connection({
    @required String scheme,
    @required String host,
    @required int port,
    String ip,
    @required this.socket,
    @required this.transport,
  }) : super(
          http2: true,
          scheme: scheme,
          host: host,
          port: port,
          ip: ip,
          data: {'socket': socket, 'transport': transport},
        );

  @override
  Future<void> close() async {
    if (!isClosed) {
      await transport.finish();
    }
  }

  @override
  bool get isClosed => !transport.isOpen;
}
