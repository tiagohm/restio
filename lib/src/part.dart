import 'dart:convert';

import 'package:restio/src/request_body.dart';

class Part {
  final Map<String, String> headers;
  final RequestBody body;

  const Part({
    this.headers = const {},
    this.body,
  });

  factory Part.form(
    String name,
    String value,
  ) {
    final headers = {
      'Content-Disposition': 'form-data; name=\"$name\"',
    };
    return Part(
      headers: headers,
      body: RequestBody.string(value),
    );
  }

  factory Part.file(
    String name,
    String filename,
    RequestBody body,
  ) {
    final headers = {
      'Content-Disposition':
          'form-data; name=\"$name\"; filename=\"$filename\"',
      'Content-Type': body.contentType.toString(),
    };
    return Part(headers: headers, body: body);
  }

  Stream<List<int>> write(
    Encoding encoding,
    String boundary,
  ) async* {
    yield utf8.encode('\r\n');
    yield utf8.encode('--');
    yield encoding.encode(boundary);
    yield utf8.encode('\r\n');

    if (headers != null) {
      for (final name in headers.keys) {
        yield encoding.encode(name);
        yield utf8.encode(': ');
        yield encoding.encode(headers[name]);
        yield utf8.encode('\r\n');
      }
    }

    yield utf8.encode('\r\n');

    if (body != null) {
      yield* body.write();
    }
  }

  @override
  String toString() {
    return 'Part { headers: $headers, body: $body }';
  }
}
