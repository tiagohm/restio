import 'dart:async';
import 'dart:io';

import 'package:restio/src/client.dart';
import 'package:restio/src/client_certificate.dart';
import 'package:restio/src/client_certificate_jar.dart';
import 'package:restio/src/compression_type.dart';
import 'package:restio/src/exceptions.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';
import 'package:restio/src/response_body.dart';
import 'package:restio/src/transport.dart';
import 'package:restio/src/utils/output_buffer.dart';

class HttpTransport implements Transport {
  @override
  final Restio client;
  HttpClient _httpClient;

  HttpTransport(this.client) : assert(client != null);

  Future<HttpClient> onCreate(
    Restio client,
    HttpClient httpClient,
  ) async {
    return httpClient;
  }

  Future<HttpClient> _buildHttpClient(
    Restio client,
    Request request,
  ) async {
    final securityContext =
        SecurityContext(withTrustedRoots: client.withTrustedRoots ?? true);

    final clientCertificate = await _pickClientCertificate(
      client.clientCertificateJar,
      request.uri.host,
      request.uri.port,
    );

    if (clientCertificate != null) {
      final certificate = clientCertificate.certificate;
      final privateKey = clientCertificate.privateKey;
      final password = clientCertificate.password;

      if (certificate != null) {
        securityContext.useCertificateChainBytes(
          certificate,
          password: password,
        );
      }

      if (privateKey != null) {
        securityContext.usePrivateKeyBytes(
          privateKey,
          password: password,
        );
      }
    }

    var httpClient = HttpClient(context: securityContext);

    httpClient = await onCreate(client, httpClient) ?? httpClient;

    httpClient.badCertificateCallback =
        ((X509Certificate cert, String host, int port) {
      // TODO: CertificatePinners: https://github.com/dart-lang/sdk/issues/35981.
      return client.verifySSLCertificate
          ? client.onBadCertificate?.call(client, cert, host, port) ?? false
          : true;
    });

    return httpClient;
  }

  Future<ClientCertificate> _pickClientCertificate(
    ClientCertificateJar jar,
    String host,
    int port,
  ) {
    return jar?.get(host, port);
  }

  @override
  Future<void> cancel() async {
    _httpClient?.close(force: true);
  }

  @override
  Future<void> close() async {
    _httpClient?.close();
  }

  @override
  Future<Response> send(Request request) async {
    HttpClientRequest clientRequest;

    _httpClient = await _buildHttpClient(client, request);

    final proxy = client.proxy;
    var hasProxy = false;

    if (proxy != null &&
        (proxy.http && request.uri.scheme == 'http' ||
            proxy.https && request.uri.scheme == 'https')) {
      hasProxy = true;
      _httpClient.findProxy = (uri) {
        return 'PROXY ${proxy.host}:${proxy.port};';
      };
    }

    try {
      if (client.connectTimeout != null && !client.connectTimeout.isNegative) {
        clientRequest = await _httpClient
            .openUrl(request.method, request.uriWithQueries)
            .timeout(client.connectTimeout);
      } else {
        clientRequest = await _httpClient.openUrl(
          request.method,
          request.uriWithQueries,
        );
      }

      if (hasProxy) {
        clientRequest.headers.add('proxy-connection', 'Keep-Alive');
      }

      // Não seguir redirecionamentos.
      clientRequest.followRedirects = false;

      // Não descomprimir a resposta.
      _httpClient.autoUncompress = false;

      // User-Agent.
      if (request.headers.has(HttpHeaders.userAgentHeader)) {
        clientRequest.headers.set(
          HttpHeaders.userAgentHeader,
          request.headers.last(HttpHeaders.userAgentHeader),
        );
      } else if (client.userAgent != null) {
        clientRequest.headers
            .set(HttpHeaders.userAgentHeader, client.userAgent);
      } else {
        clientRequest.headers.set(HttpHeaders.userAgentHeader, 'Restio/0.1.0');
      }

      // Content-Type.
      if (!request.headers.has(HttpHeaders.contentTypeHeader) &&
          request.body?.contentType != null) {
        clientRequest.headers.contentType =
            request.body.contentType.toContentType();
      }

      // Headers.
      request.headers?.forEach((key, value) {
        switch (key) {
          case HttpHeaders.userAgentHeader:
            break;
          default:
            clientRequest.headers.add(key, value);
        }
      });

      // Body.
      if (request.body != null) {
        final future = _send(clientRequest, request, client);
        // Escreve os dados.
        if (client.writeTimeout != null && !client.writeTimeout.isNegative) {
          await future.timeout(client.writeTimeout);
        } else {
          await future;
        }
      }

      // Resposta.
      DateTime receivedAt;
      HttpClientResponse response;

      if (client.receiveTimeout != null && !client.receiveTimeout.isNegative) {
        response = await clientRequest
            .close()
            .timeout(client.receiveTimeout)
            .whenComplete(() => receivedAt = DateTime.now());
      } else {
        response = await clientRequest
            .close()
            .whenComplete(() => receivedAt = DateTime.now());
      }

      // Monta a resposta.
      final res = Response(
        connectRequest: request,
        code: response.statusCode,
        headers: _obtainHeadersfromHttpHeaders(response.headers),
        message: response.reasonPhrase,
        connectionInfo: response.connectionInfo,
        receivedAt: receivedAt,
        certificate: response.certificate,
      );

      return res.copyWith(
        body: ResponseBody.fromStream(
          response.cast<List<int>>(),
          contentType: MediaType.fromContentType(response.headers.contentType),
          contentLength: response.headers.contentLength,
          compressionType: _obtainCompressType(response),
          onProgress: (sent, total, done) {
            client.onDownloadProgress?.call(res, sent, total, done);
          },
        ),
      );
    } on TimeoutException {
      throw TimedOutException(''); // connect time out
    }
  }

  static CompressionType _obtainCompressType(HttpClientResponse response) {
    final contentEncoding = response.headers[HttpHeaders.contentEncodingHeader];

    if (contentEncoding != null && contentEncoding.isNotEmpty) {
      switch (contentEncoding[0]) {
        case 'gzip':
          return CompressionType.gzip;
        case 'deflate':
          return CompressionType.deflate;
        case 'brotli':
          return CompressionType.brotli;
      }
    }

    return CompressionType.notCompressed;
  }

  static Headers _obtainHeadersfromHttpHeaders(
    HttpHeaders httpHeaders,
  ) {
    final headers = HeadersBuilder();
    httpHeaders.forEach(headers.add);
    return headers.build();
  }

  static Future<int> _send(
    HttpClientRequest clientRequest,
    Request request,
    Restio client,
  ) async {
    final sink = OutputBuffer();
    final completer = Completer<int>();
    const totalBytes = -1;
    var progressBytes = 0;

    request.body.write().listen(
      (List<int> chunk) {
        sink.add(chunk);

        progressBytes += chunk.length;

        client.onUploadProgress
            ?.call(request, progressBytes, totalBytes, false);
      },
      onDone: () {
        sink.close();

        client.onUploadProgress
            ?.call(request, progressBytes, sink.length, true);

        clientRequest.contentLength = sink.length;
        clientRequest.add(sink.bytes);

        completer.complete(sink.length);
      },
      onError: completer.completeError,
      cancelOnError: true,
    );

    return completer.future;
  }
}
