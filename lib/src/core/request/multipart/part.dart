import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:restio/src/core/request/request_body.dart';

class Part extends Equatable {
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
    final body = RequestBody.string(value);

    final headers = {
      'Content-Disposition': 'form-data; name="$name"',
      'Content-Type': body.contentType.toHeaderString(),
    };

    return Part(headers: headers, body: body);
  }

  factory Part.file(
    String name,
    String filename,
    RequestBody body,
  ) {
    final headers = {
      'Content-Disposition': 'form-data; name="$name"; filename="$filename"',
      'Content-Type': body.contentType.toHeaderString(),
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
  List<Object> get props => [headers, body];

  @override
  String toString() {
    return 'Part { headers: $headers, body: $body }';
  }
}
