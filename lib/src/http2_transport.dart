import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http2/http2.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/compression_type.dart';
import 'package:restio/src/exceptions.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';
import 'package:restio/src/response_body.dart';
import 'package:restio/src/transport.dart';
import 'package:restio/src/utils/output_buffer.dart';

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

      final uri = request.uriWithQueries;

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
      if (request.headers.has(HttpHeaders.userAgentHeader)) {
        headers.add(
          Header.ascii(HttpHeaders.userAgentHeader,
              request.headers.last(HttpHeaders.userAgentHeader)),
        );
      } else if (client.userAgent != null) {
        headers
            .add(Header.ascii(HttpHeaders.userAgentHeader, client.userAgent));
      } else {
        headers.add(Header.ascii(HttpHeaders.userAgentHeader, 'Restio/0.1.0'));
      }

      // Content-Type.
      if (!request.headers.has(HttpHeaders.contentTypeHeader) &&
          request.body?.contentType != null) {
        headers.add(
          Header.ascii(
            HttpHeaders.contentTypeHeader,
            request.body.contentType.toString(),
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
      request.headers?.forEach((key, value) {
        headers.add(Header.ascii(key, value));
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
    return _makeResponse(client, request, _stream);
  }

  Future<SecureSocket> _createSocket(Request request) async {
    return SecureSocket.connect(
      request.uri.host,
      request.uri.port,
      timeout: client.connectTimeout,
      context: SecurityContext(withTrustedRoots: client.withTrustedRoots),
      supportedProtocols: ['h2'],
      onBadCertificate: (cert) {
        return !client.verifySSLCertificate ||
            (client?.onBadCertificate?.call(
                  cert,
                  request.uri.host,
                  request.uri.port,
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
    const totalBytes = -1;
    var progressBytes = 0;

    if (request.body != null) {
      request.body.write().listen(
        (chunk) {
          sink.add(chunk);

          progressBytes += chunk.length;

          client.onUploadProgress?.call(progressBytes, totalBytes, false);
        },
        onDone: () {
          sink.close();

          client.onUploadProgress?.call(progressBytes, sink.length, true);

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
    Request request,
    ClientTransportStream stream,
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
          code: code,
          headers: headers.build(),
          // message: response.reasonPhrase,
          // connectionInfo: ,
          receivedAt: DateTime.now(),
          // certificate: response.certificate,
        );

        res = res.copyWith(
          body: ResponseBody.stream(
            data.stream,
            contentType: _obtainMediaType(res.headers),
            contentLength: _obtainContentLength(res.headers),
            compressionType: _obtainCompressType(res.headers),
            onProgress: client.onDownloadProgress,
          ),
        );

        completer.complete(res);
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
    final contentType = headers.first(HttpHeaders.contentTypeHeader);

    try {
      return MediaType.fromContentType(ContentType.parse(contentType[0]));
    } catch (e) {
      return MediaType.octetStream;
    }
  }

  static int _obtainContentLength(Headers headers) {
    final contentLength = headers.first(HttpHeaders.contentLengthHeader);

    try {
      return int.parse(contentLength[0]);
    } on FormatException {
      return -1;
    }
  }

  static CompressionType _obtainCompressType(Headers headers) {
    final contentEncoding = headers.first(HttpHeaders.contentEncodingHeader);
    return parseContentEncoding(contentEncoding);
  }
}
