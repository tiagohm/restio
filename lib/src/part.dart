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
      body: RequestBody.fromString(value),
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
    yield encoding.encode('\r\n--$boundary\r\n');

    if (headers != null) {
      for (final name in headers.keys) {
        yield encoding.encode('$name: ${headers[name]}\r\n');
      }
    }

    yield encoding.encode('\r\n');

    if (body != null) {
      yield* body.write();
    }
  }

  @override
  String toString() {
    return 'Part { headers: $headers, body: $body }';
  }
}
