import 'dart:async';
import 'dart:io';

import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/call/cancellable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_event.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/transport/transport.dart';

class HttpTransport implements Transport {
  @override
  final Restio client;

  Connection _connection;
  HttpClient _httpClient;

  HttpTransport(this.client) : assert(client != null);

  @override
  Future<void> cancel(String message) async {
    // Irá fechar todas as conexões para um determinado [scheme:host:port].
    // _httpClient?.close(force: true);
    await _connection.cancel();
  }

  @override
  Future<Response> send(
    final Request request, {
    Cancellable cancellable,
  }) async {
    final options = request.options;

    HttpClientRequest clientRequest;
    HttpClientResponse response;

    var uri = request.uri;

    final state =
        (await client.connectionPool.get(client, request, cancellable))..stop();
    final address = state.connection.address.ip;

    if (address != null) {
      uri = uri.copyWith(host: address.toString());
    }

    _connection = state.connection;
    _httpClient = _connection.data[0];

    try {
      options.onEvent
          ?.call(ConnectStart(request, uri.host, _connection.address.proxy));

      if (options.connectTimeout != null &&
          !options.connectTimeout.isNegative) {
        clientRequest = await _httpClient
            .openUrl(request.method, uri.toUri())
            .timeout(options.connectTimeout);
      } else {
        clientRequest = await _httpClient.openUrl(
          request.method,
          uri.toUri(),
        );
      }

      options.onEvent?.call(ConnectEnd(request));

      // Não seguir redirecionamentos.
      clientRequest.followRedirects = false;

      // Não descomprimir a resposta.
      _httpClient.autoUncompress = false;

      // Connection.
      if (!request.headers.has(HttpHeaders.connectionHeader)) {
        clientRequest.persistentConnection =
            request.options.persistentConnection;
      }

      // Headers.
      request.headers?.forEach((item) {
        switch (item.name.toLowerCase()) {
          case HttpHeaders.userAgentHeader:
          case HttpHeaders.acceptEncodingHeader:
            clientRequest.headers.set(
              item.name,
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

      // Proxy.
      if (state.connection.address.proxy != null) {
        clientRequest.headers.set(
          'Proxy-Connection',
          'Keep-Alive',
          preserveHeaderCase: true,
        );
      }

      // Host.
      if (!request.headers.has(HttpHeaders.hostHeader) && address != null) {
        clientRequest.headers.set(
          'Host',
          request.uri.toHostHeader(),
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
        localPort: response.connectionInfo?.localPort,
        certificate: response.certificate,
        address: address,
        onClose: () async {
          if (!state.isClosed) {
            state.start();
          }
        },
      );

      return res.copyWith(
        body: ResponseBody.stream(
          response,
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
    } finally {
      if (!request.options.persistentConnection ||
          response?.persistentConnection == false) {
        await _connection.close();
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
        sink.close();
        client.onUploadProgress?.call(request, 0, total, true);
      },
    );

    final stream = request.body.write().transform(listener);

    if (request.body.contentLength == null || request.body.contentLength < 0) {
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
