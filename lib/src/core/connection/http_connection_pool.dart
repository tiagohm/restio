import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/connection/connection_pool.dart';
import 'package:restio/src/core/request/request.dart';

class HttpConnectionPool extends ConnectionPool<HttpClient> {
  HttpConnectionPool(
    Restio client, {
    Duration idleTimeout,
  }) : super(client, idleTimeout: idleTimeout);

  @override
  Future<HttpClient> makeClient(Request request) async {
    final options = request.options;

    final context =
        SecurityContext(withTrustedRoots: client.withTrustedRoots ?? true);

    // Busca o certificado.
    final certificate = options.certificate ??
        client.certificates?.firstWhere(
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
          (client.onBadCertificate?.call(cert, host, port) ?? false);
    };

    return httpClient;
  }

  @override
  Future<Connection<HttpClient>> makeConnection(
    Request request,
    HttpClient client, [
    String ip,
  ]) async {
    final uri = request.uri;

    return _HttpConnection(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.effectivePort,
      ip: ip,
      client: client,
    );
  }
}

class _HttpConnection extends Connection<HttpClient> {
  var _isClosed = false;

  _HttpConnection({
    @required String scheme,
    @required String host,
    @required int port,
    String ip,
    @required HttpClient client,
  }) : super(scheme: scheme, host: host, port: port, ip: ip, client: client);

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
