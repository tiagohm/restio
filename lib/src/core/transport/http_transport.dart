import 'dart:async';
import 'dart:io';

import 'package:ip/ip.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/transport/transport.dart';

class HttpTransport implements Transport {
  @override
  final Restio client;

  Connection<HttpClient> _connection;

  HttpTransport(this.client) : assert(client != null);

  @override
  Future<void> cancel() async {
    // Irá fechar todas as conexões para um determinado [scheme:host:port].
    _connection?.client?.close(force: true);
  }

  @override
  Future<Response> send(final Request request) async {
    final options = request.options;

    HttpClientRequest clientRequest;
    HttpClientResponse response;
    IpAddress address;

    var uri = request.uri;

    // Verificar se não é um IP.
    // Busca o real endereço (IP) do host através de um DNS.
    if (options.dns != null && !isIp(uri.host)) {
      final addresses = await options.dns.lookup(uri.host);

      if (addresses != null && addresses.isNotEmpty) {
        address = addresses[0];
        uri = uri.copyWith(host: address.toString());
      }
    }

    final state = (await client.httpConnectionPool.get(
      request,
      address?.toString(),
    ));

    state.stop();

    _connection = state.connection;
    final httpClient = _connection.client;

    final proxy = options.proxy;
    var hasProxy = false;

    // Proxy.
    if (proxy != null &&
        (proxy.http && uri.scheme == 'http' ||
            proxy.https && uri.scheme == 'https')) {
      hasProxy = true;
      httpClient.findProxy = (uri) {
        return 'PROXY ${proxy.host}:${proxy.port};';
      };
    }

    try {
      if (options.connectTimeout != null &&
          !options.connectTimeout.isNegative) {
        clientRequest = await httpClient
            .openUrl(request.method, uri.toUri())
            .timeout(options.connectTimeout);
      } else {
        clientRequest = await httpClient.openUrl(
          request.method,
          uri.toUri(),
        );
      }

      if (hasProxy) {
        clientRequest.headers.add(
          'Proxy-Connection',
          'Keep-Alive',
          preserveHeaderCase: true,
        );
      }

      // Não seguir redirecionamentos.
      clientRequest.followRedirects = false;

      // Não descomprimir a resposta.
      httpClient.autoUncompress = false;

      // User-Agent.
      if (!request.headers.has(HttpHeaders.userAgentHeader)) {
        if (options.userAgent != null) {
          clientRequest.headers.set(
            'User-Agent',
            options.userAgent,
            preserveHeaderCase: true,
          );
        } else {
          clientRequest.headers.set(
            'User-Agent',
            'Restio/${Restio.version}',
            preserveHeaderCase: true,
          );
        }
      }

      // Content-Type.
      if (!request.headers.has(HttpHeaders.contentTypeHeader) &&
          request.body?.contentType != null) {
        clientRequest.headers.set(
          'Content-Type',
          request.body.contentType.toHeaderString(),
          preserveHeaderCase: true,
        );
      }

      // Accept-Encoding.
      if (!request.headers.has(HttpHeaders.acceptEncodingHeader)) {
        clientRequest.headers.set(
          'Accept-Encoding',
          'gzip, deflate, br',
          preserveHeaderCase: true,
        );
      }

      // Connection.
      if (!request.headers.has(HttpHeaders.connectionHeader)) {
        clientRequest.persistentConnection = true;
      }

      // Headers.
      request.headers?.forEach((item) {
        switch (item.name.toLowerCase()) {
          case HttpHeaders.userAgentHeader:
            clientRequest.headers.set(
              'User-Agent',
              item.value,
              preserveHeaderCase: true,
            );
            break;
          default:
            clientRequest.headers.add(
              item.name,
              item.value,
              preserveHeaderCase: true,
            );
        }
      });

      // Host.
      if (!request.headers.has(HttpHeaders.hostHeader) && address != null) {
        clientRequest.headers.set(
          'Host',
          request.uri.host,
          preserveHeaderCase: true,
        );
      }

      // Body.
      if (request.body != null) {
        final future = _writeBody(clientRequest, request, client);
        // Escreve os dados.
        if (options.writeTimeout != null && !options.writeTimeout.isNegative) {
          await future.timeout(options.writeTimeout);
        } else {
          await future;
        }
      }

      if (options.receiveTimeout != null &&
          !options.receiveTimeout.isNegative) {
        response = await clientRequest.close().timeout(options.receiveTimeout);
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
        address: address,
        onClose: () async {
          state.start();
        },
      );

      return res.copyWith(
        body: ResponseBody.stream(
          response.cast<List<int>>(),
          contentType: MediaType.fromContentType(response.headers.contentType),
          contentLength: response.headers.contentLength,
        ),
      );
    } catch (e) {
      if (e is TimeoutException) {
        throw const TimedOutException('');
      } else {
        try {
          // Evita vazamento de memória quando algum erro ocorrer.
          await response?.drain();
        } catch (e) {
          // nada.
        }

        rethrow;
      }
    }
  }

  static Headers _obtainHeadersfromHttpHeaders(
    HttpHeaders httpHeaders,
  ) {
    final headers = HeadersBuilder();
    httpHeaders.forEach(headers.add);
    return headers.build();
  }

  static Future<void> _writeBody(
    HttpClientRequest clientRequest,
    Request request,
    Restio client,
  ) async {
    var total = 0;

    final listener = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (chunk, sink) {
        sink.add(chunk);
        total += chunk.length;
        client.onUploadProgress?.call(request, chunk.length, total, false);
      },
      handleDone: (sink) {
        client.onUploadProgress?.call(request, 0, total, true);
        sink.close();
      },
    );

    final stream = request.body.write().transform(listener);

    if (request.body.contentLength == null || request.body.contentLength <= 0) {
      final data = await readStream(stream);

      clientRequest.headers.add(
        'Content-Length',
        data.length.toString(),
        preserveHeaderCase: true,
      );

      clientRequest.add(data);
    } else {
      clientRequest.headers.add(
        'Content-Length',
        request.body.contentLength.toString(),
        preserveHeaderCase: true,
      );

      await clientRequest.addStream(stream);
    }
  }
}
