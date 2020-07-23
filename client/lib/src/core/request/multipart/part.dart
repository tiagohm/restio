import 'dart:convert';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:path/path.dart';
import 'package:restio/src/core/request/header/media_type.dart';
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
      'Content-Type': body.contentType.value,
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
      'Content-Type': body.contentType.value,
    };

    return Part(headers: headers, body: body);
  }

  factory Part.fromFile(
    String name,
    File file, {
    String filename,
    MediaType contentType,
    String charset,
    int start,
    int end,
  }) {
    filename ??= basename(file.path);

    return Part.file(
      name,
      filename,
      RequestBody.file(
        file,
        contentType: contentType,
        charset: charset,
        start: start,
        end: end,
      ),
    );
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
