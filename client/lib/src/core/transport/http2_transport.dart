import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http2/http2.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/call/cancellable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/response/server_push.dart';
import 'package:restio/src/core/transport/transport.dart';

class Http2Transport implements Transport {
  @override
  final Restio client;

  ClientTransportStream _stream;
  Connection _connection;
  Socket _socket;
  ClientTransportConnection _transport;

  Http2Transport(this.client);

  @override
  Future<void> cancel(String message) async {
    _socket?.destroy();
  }

  @override
  Future<Response> send(
    final Request request, {
    Cancellable cancellable,
  }) async {
    final options = request.options;

    try {
      final state =
          (await client.connectionPool.get(client, request, cancellable));

      _connection = state.connection;
      _socket = state.connection.data[0];
      _transport = state.connection.data[1];

      final uri = request.uri.toUri();
      var path = uri.path;

      if (uri.query.trim().isNotEmpty) {
        path += '?${uri.query}';
      }

      if (!path.startsWith('/')) {
        path = '/$path';
      }

      final headers = [
        Header.ascii(':method', request.method),
        Header.ascii(':path', path),
        Header.ascii(':scheme', uri.scheme),
        Header.ascii(':authority', uri.host),
      ];

      // Headers.
      request.headers?.forEach((item) {
        // https://tools.ietf.org/html/rfc7540#section-8.1.2
        headers.add(Header.ascii(item.name.toLowerCase(), item.value));
      });

      // Body.
      final future = _makeRequest(request, client, _transport, headers);
      if (options.writeTimeout != null && !options.writeTimeout.isNegative) {
        _stream = await future.timeout(options.writeTimeout);
      } else {
        _stream = await future;
      }

      await _stream.outgoingMessages.close();

      // Monta a resposta.
      final response =
          _makeResponse(client, request, _stream, _socket, _connection);

      if (options.receiveTimeout != null &&
          !options.receiveTimeout.isNegative) {
        return await response.timeout(options.receiveTimeout);
      } else {
        return await response;
      }
    } on TimeoutException {
      throw const TimedOutException(''); // Connect time out.
    } finally {
      if (!request.options.persistentConnection) {
        await _connection.close();
      }
    }
  }

  static Future<ClientTransportStream> _makeRequest(
    Request request,
    Restio client,
    ClientTransportConnection transport,
    List<Header> headers,
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

    final transportStream = transport.makeRequest(
      headers,
      endStream: request.body == null,
    );

    if (request.body != null) {
      final stream = request.body.write().transform(listener);
      final data = await readStream(stream);
      headers
          .add(Header.ascii(HttpHeaders.contentLengthHeader, '${data.length}'));

      transportStream.outgoingMessages.add(DataStreamMessage(
        data,
        endStream: true,
      ));
    }

    return transportStream;
  }

  static Future<Response> _makeResponse(
    Restio client,
    Request request,
    ClientTransportStream stream,
    Socket socket,
    Connection connection,
  ) {
    StreamController<ServerPush> serverPushController;
    final completer = Completer<Response>();
    final dataController = StreamController<List<int>>();
    final allowServerPushes = request.options.allowServerPushes;

    if (allowServerPushes) {
      serverPushController = StreamController<ServerPush>(sync: true);
    }

    stream.incomingMessages.listen(
      (msg) {
        if (msg is HeadersStreamMessage) {
          final headersBuilder = _convertHeaders(msg.headers);
          final code = headersBuilder.first(':status')?.asInt ?? 0;
          headersBuilder.removeAll(':status');

          final headers = headersBuilder?.build() ?? Headers.empty;
          final contentType = _mediaType(headers);
          final contentLength = _contentLength(headers);

          final res = Response(
            body: ResponseBody.stream(
              dataController.stream,
              contentType: contentType,
              contentLength: contentLength,
            ),
            code: code,
            headers: headers,
            localPort: socket.port,
            pushes: allowServerPushes
                ? serverPushController.stream
                : const Stream.empty(),
            address: connection.address?.ip,
          );

          completer.complete(res);
        } else if (msg is DataStreamMessage) {
          dataController.add(msg.bytes);
        }
      },
      onDone: dataController.close,
      onError: (e, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }

        dataController.addError(e, stackTrace);
      },
      cancelOnError: true,
    );

    if (allowServerPushes) {
      _handlePeerPushes(stream.peerPushes, socket.port)
          .pipe(serverPushController);
    }

    return completer.future;
  }
}

MediaType _mediaType(Headers headers) {
  final contentType = headers.value(HttpHeaders.contentTypeHeader);

  try {
    return MediaType.fromContentType(ContentType.parse(contentType));
  } catch (e) {
    return MediaType.octetStream;
  }
}

int _contentLength(Headers headers) {
  final contentLength = headers.value(HttpHeaders.contentLengthHeader);

  try {
    return int.parse(contentLength);
  } catch (e) {
    return -1;
  }
}

HeadersBuilder _convertHeaders(List<Header> headers) {
  final builder = HeadersBuilder();

  for (final header in headers) {
    final name = ascii.decode(header.name);
    final value = ascii.decode(header.value);
    builder.add(name, value);
  }

  return builder;
}

Stream<ServerPush> _handlePeerPushes(
  Stream<TransportStreamPush> serverPushes,
  int localPort,
) {
  final pushesController = StreamController<ServerPush>();

  serverPushes.listen(
    (push) {
      final responseCompleter = Completer<Response>();

      final serverPush = ServerPush(
        _convertHeaders(push.requestHeaders).build(),
        responseCompleter.future,
      );

      pushesController.add(serverPush);

      final dataController = StreamController<List<int>>();

      push.stream.incomingMessages.listen(
        (msg) {
          if (msg is HeadersStreamMessage) {
            final headersBuilder = _convertHeaders(msg.headers);
            final code = headersBuilder.first(':status')?.asInt ?? 0;
            headersBuilder.removeAll(':status');

            final headers = headersBuilder?.build() ?? Headers.empty;
            final contentType = _mediaType(headers);
            final contentLength = _contentLength(headers);

            final res = Response(
              body: ResponseBody.stream(
                dataController.stream,
                contentType: contentType,
                contentLength: contentLength,
              ),
              code: code,
              headers: headers,
              localPort: localPort,
              pushes: const Stream.empty(),
            );

            responseCompleter.complete(res);
          } else {
            dataController.add((msg as DataStreamMessage).bytes);
          }
        },
        onDone: dataController.close,
        onError: (e, stackTrace) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.completeError(e, stackTrace);
          }

          dataController.addError(e, stackTrace);
        },
      );
    },
    onDone: pushesController.close,
    onError: pushesController.addError,
  );

  return pushesController.stream;
}
