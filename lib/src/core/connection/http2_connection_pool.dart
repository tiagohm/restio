import 'dart:io';

import 'package:http2/http2.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/connection/connection_pool.dart';
import 'package:restio/src/core/connection/connection_state.dart';
import 'package:restio/src/core/request/request.dart';

class Http2ConnectionPool extends ConnectionPool<List> {
  Http2ConnectionPool(
    Restio client, {
    Duration idleTimeout,
  }) : super(client, idleTimeout: idleTimeout);

  @override
  Future<List> makeClient(Request request) async {
    final options = request.options;

    Socket socket;

    if (options.connectTimeout != null && !options.connectTimeout.isNegative) {
      socket = await _createSocket(request).timeout(options.connectTimeout);
    } else {
      socket = await _createSocket(request);
    }

    final settings =
        ClientSettings(allowServerPushes: options.allowServerPushes);

    return [
      socket,
      ClientTransportConnection.viaSocket(socket, settings: settings)
    ];
  }

  Future<Socket> _createSocket(Request request) {
    final options = request.options;
    final port = request.uri.effectivePort;

    return request.uri.scheme == 'https'
        ? SecureSocket.connect(
            request.uri.host,
            port,
            context: SecurityContext(withTrustedRoots: client.withTrustedRoots),
            supportedProtocols: const [
              'h2-14',
              'h2-15',
              'h2-16',
              'h2-17',
              'h2'
            ],
            onBadCertificate: (cert) {
              return !options.verifySSLCertificate ||
                  (client?.onBadCertificate?.call(
                        cert,
                        request.uri.host,
                        port,
                      ) ??
                      false);
            },
          )
        : Socket.connect(request.uri.host, port);
  }

  @override
  Future<ConnectionState<List>> makeState(
    String key,
    Connection<List> connection,
    void Function() onTimeout,
  ) async {
    final state = await super.makeState(key, connection, onTimeout);
    final transport = state.connection.client[1] as ClientTransportConnection;

    transport.onActiveStateChanged = (active) {
      if (active) {
        state.stop();
      } else {
        state.start();
      }
    };

    return state;
  }

  @override
  Future<Connection<List>> makeConnection(
    Request request,
    List client, [
    String ip,
  ]) async {
    final uri = request.uri;

    return _Http2Connection(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.effectivePort,
      ip: ip,
      client: client,
    );
  }
}

class _Http2Connection extends Connection<List> {
  _Http2Connection({
    @required String scheme,
    @required String host,
    @required int port,
    String ip,
    @required List client,
  }) : super(scheme: scheme, host: host, port: port, ip: ip, client: client);

  @override
  Future<void> close() async {
    if (!isClosed) {
      await client[1].finish();
    }
  }

  @override
  bool get isClosed => !client[1].isOpen;
}
