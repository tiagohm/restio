import 'dart:async';
import 'dart:io';

import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/http/transport.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/compression_type.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/response/response_body.dart';
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

    final clientCertificate = await client.clientCertificateJar?.get(
      request.uri.host,
      request.uri.effectivePort,
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

    httpClient.badCertificateCallback = (cert, host, port) {
      // TODO: CertificatePinners: https://github.com/dart-lang/sdk/issues/35981.
      return !client.verifySSLCertificate ||
          (client.onBadCertificate?.call(cert, host, port) ?? false);
    };

    return httpClient;
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
  Future<Response> send(final Request request) async {
    HttpClientRequest clientRequest;

    _httpClient = await _buildHttpClient(client, request);

    final proxy = client.proxy;
    var hasProxy = false;

    // Usar proxy.
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
            .openUrl(request.method, request.uri.toUri())
            .timeout(client.connectTimeout);
      } else {
        clientRequest = await _httpClient.openUrl(
          request.method,
          request.uri.toUri(),
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
      if (!request.headers.has(HttpHeaders.userAgentHeader)) {
        if (client.userAgent != null) {
          clientRequest.headers
              .set(HttpHeaders.userAgentHeader, client.userAgent);
        } else {
          clientRequest.headers
              .set(HttpHeaders.userAgentHeader, 'Restio/${Restio.version}');
        }
      }

      // Content-Type.
      if (!request.headers.has(HttpHeaders.contentTypeHeader) &&
          request.body?.contentType != null) {
        clientRequest.headers.contentType =
            request.body.contentType.toContentType();
      }

      // Accept-Encoding.
      if (!request.headers.has(HttpHeaders.acceptEncodingHeader)) {
        clientRequest.headers
            .set(HttpHeaders.acceptEncodingHeader, 'gzip, deflate, br');
      }

      // Connection.
      if (!request.headers.has(HttpHeaders.connectionHeader)) {
        clientRequest.headers.set(HttpHeaders.connectionHeader, 'Keep-Alive');
      }

      // Headers.
      request.headers?.forEach((item) {
        switch (item.name) {
          case HttpHeaders.userAgentHeader:
            clientRequest.headers.set(item.name, item.value);
            break;
          default:
            clientRequest.headers.add(item.name, item.value);
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
      HttpClientResponse response;

      if (client.receiveTimeout != null && !client.receiveTimeout.isNegative) {
        response = await clientRequest.close().timeout(client.receiveTimeout);
      } else {
        response = await clientRequest.close();
      }

      // Monta a resposta.
      final res = Response(
        body: null,
        code: response.statusCode,
        headers: _obtainHeadersfromHttpHeaders(response.headers),
        message: response.reasonPhrase,
        connectionInfo: response.connectionInfo,
        certificate: response.certificate,
      );

      return res.copyWith(
        body: ResponseBody.stream(
          response.cast<List<int>>(),
          contentType: MediaType.fromContentType(response.headers.contentType),
          contentLength: response.headers.contentLength,
          compressionType: _obtainCompressType(response),
          onProgress: client.onDownloadProgress,
        ),
      );
    } on TimeoutException {
      throw const TimedOutException(''); // connect time out
    }
  }

  static CompressionType _obtainCompressType(HttpClientResponse response) {
    final contentEncoding = response.headers[HttpHeaders.contentEncodingHeader];
    return contentEncoding != null && contentEncoding.isNotEmpty
        ? obtainCompressionType(contentEncoding[0])
        : CompressionType.notCompressed;
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
      (chunk) {
        sink.add(chunk);

        progressBytes += chunk.length;

        client.onUploadProgress?.call(progressBytes, totalBytes, false);
      },
      onDone: () {
        sink.close();

        client.onUploadProgress?.call(progressBytes, sink.length, true);

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
