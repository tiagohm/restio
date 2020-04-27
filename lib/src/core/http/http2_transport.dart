import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http2/http2.dart';
import 'package:restio/src/common/output_buffer.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/http/transport.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

class Http2Transport implements Transport {
  @override
  final Restio client;
  ClientTransportStream _stream;
  ClientTransportConnection _transport;

  Http2Transport(this.client);

  @override
  Future<void> cancel() async {
    _stream?.terminate();
  }

  @override
  Future<void> close() async {
    await _transport?.finish();
  }

  @override
  Future<Response> send(final Request request) async {
    SecureSocket socket;

    try {
      socket = await _createSocket(request);
      _transport = ClientTransportConnection.viaSocket(socket);

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

      // User-Agent.
      if (!request.headers.has(HttpHeaders.userAgentHeader)) {
        if (client.userAgent != null) {
          headers
              .add(Header.ascii(HttpHeaders.userAgentHeader, client.userAgent));
        } else {
          headers.add(Header.ascii(
              HttpHeaders.userAgentHeader, 'Restio/${Restio.version}'));
        }
      }

      // Content-Type.
      if (!request.headers.has(HttpHeaders.contentTypeHeader) &&
          request.body?.contentType != null) {
        headers.add(
          Header.ascii(
            HttpHeaders.contentTypeHeader,
            request.body.contentType.toHeaderString(),
          ),
        );
      }

      // Accept-Encoding.
      if (!request.headers.has(HttpHeaders.acceptEncodingHeader)) {
        headers.add(
          Header.ascii(
            HttpHeaders.acceptEncodingHeader,
            'gzip, deflate, br',
          ),
        );
      }

      // Headers.
      request.headers?.forEach((item) {
        headers.add(Header.ascii(item.name, item.value));
      });

      // Body.
      final future = _makeRequest(request, client, _transport, headers);
      if (client.writeTimeout != null && !client.writeTimeout.isNegative) {
        _stream = await future.timeout(client.writeTimeout);
      } else {
        _stream = await future;
      }

      await _stream.outgoingMessages.close();
    } on TimeoutException {
      throw const TimedOutException(''); // Connect time out.
    }

    // Monta a resposta.
    return _makeResponse(client, _stream, socket);
  }

  Future<SecureSocket> _createSocket(Request request) async {
    final port = request.uri.effectivePort;

    return SecureSocket.connect(
      request.uri.host,
      port,
      timeout: client.connectTimeout,
      context: SecurityContext(withTrustedRoots: client.withTrustedRoots),
      supportedProtocols: ['h2'],
      onBadCertificate: (cert) {
        return !client.verifySSLCertificate ||
            (client?.onBadCertificate?.call(
                  cert,
                  request.uri.host,
                  port,
                ) ??
                false);
      },
    );
  }

  static Future<ClientTransportStream> _makeRequest(
    Request request,
    Restio client,
    ClientTransportConnection transport,
    List<Header> headers,
  ) async {
    final sink = OutputBuffer();
    final completer = Completer<ClientTransportStream>();
    var progressBytes = 0;

    if (request.body != null) {
      request.body.write().listen(
        (chunk) {
          sink.add(chunk);

          progressBytes += chunk.length;

          client.onUploadProgress?.call(request, progressBytes, -1, false);
        },
        onDone: () {
          sink.close();

          client.onUploadProgress
              ?.call(request, progressBytes, sink.length, true);

          headers.add(
            Header.ascii(HttpHeaders.contentLengthHeader, '${sink.length}'),
          );

          final stream = transport.makeRequest(
            headers,
            endStream: false,
          );

          stream.outgoingMessages.add(DataStreamMessage(
            sink.bytes,
            endStream: true,
          ));

          completer.complete(stream);
        },
        onError: completer.completeError,
        cancelOnError: true,
      );
    } else {
      final stream = transport.makeRequest(
        headers,
        endStream: true,
      );
      completer.complete(stream);
    }

    return completer.future;
  }

  static Future<Response> _makeResponse(
    Restio client,
    ClientTransportStream stream,
    SecureSocket socket,
  ) {
    final completer = Completer<Response>();
    final data = StreamController<List<int>>();
    final headers = HeadersBuilder();
    var code = 0;

    stream.incomingMessages.listen(
      (message) async {
        // Headers.
        if (message is HeadersStreamMessage) {
          for (final header in message.headers) {
            final name = utf8.decode(header.name);
            final value = utf8.decode(header.value);

            // Status.
            if (name == ':status') {
              code = int.parse(value);
            } else {
              headers.add(name, value);
            }
          }
        } else if (message is DataStreamMessage) {
          data.add(message.bytes);
        }
      },
      onDone: () {
        data.close();

        var res = Response(
          body: null,
          code: code,
          headers: headers.build(),
        );

        res = res.copyWith(
          body: ResponseBody.stream(
            data.stream,
            contentType: _obtainMediaType(res.headers),
            contentLength: _obtainContentLength(res.headers),
          ),
        );

        completer.complete(res);

        socket.destroy();
      },
      onError: (e) {
        if (!completer.isCompleted) {
          completer.completeError(e, StackTrace.current);
        } else {
          data.addError(e);
        }
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  static MediaType _obtainMediaType(Headers headers) {
    final contentType = headers.value(HttpHeaders.contentTypeHeader);

    try {
      return MediaType.fromContentType(ContentType.parse(contentType));
    } catch (e) {
      return MediaType.octetStream;
    }
  }

  static int _obtainContentLength(Headers headers) {
    final contentLength = headers.value(HttpHeaders.contentLengthHeader);

    try {
      return int.parse(contentLength);
    } catch (e) {
      return -1;
    }
  }
}
