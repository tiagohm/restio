import 'dart:convert';
import 'dart:io';

import 'package:restio/src/media_type.dart';

abstract class RequestBody {
  MediaType get contentType;

  Stream<List<int>> write();

  factory RequestBody.empty() => RequestBody.fromBytes(const []);

  factory RequestBody.fromBytes(
    List<int> data, {
    MediaType contentType,
  }) {
    return _BytesRequestBody(
      contentType: contentType ?? MediaType.octetStream,
      data: data,
    );
  }

  factory RequestBody.fromString(
    String text, {
    MediaType contentType,
  }) {
    return _StringRequestBody(
      contentType: contentType ?? MediaType.text,
      text: text,
    );
  }

  factory RequestBody.fromFile(
    File file, {
    MediaType contentType,
  }) {
    assert(file != null);

    return _FileRequestBody(
      contentType: contentType ?? MediaType.fromFile(file.path),
      file: file,
    );
  }

  factory RequestBody.fromJson(Object o) {
    return RequestBody.fromString(
      json.encoder.convert(o),
      contentType: MediaType.json,
    );
  }
}

class _StringRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  final String text;

  const _StringRequestBody({
    this.contentType,
    this.text,
  });

  @override
  Stream<List<int>> write() async* {
    final encoding = contentType?.encoding;

    if (encoding != null) {
      yield encoding.encode(text);
    } else {
      yield utf8.encode(text);
    }
  }

  @override
  String toString() {
    return 'StringRequestBody { text: $text, contentType: $contentType }';
  }
}

class _BytesRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  final List<int> data;

  const _BytesRequestBody({
    this.contentType,
    this.data,
  });

  @override
  Stream<List<int>> write() async* {
    yield data;
  }

  @override
  String toString() {
    return 'BytesRequestBody { data: $data, contentType: $contentType }';
  }
}

class _FileRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  final File file;

  const _FileRequestBody({
    this.contentType,
    this.file,
  });

  @override
  Stream<List<int>> write() async* {
    yield await file.readAsBytes();
  }

  @override
  String toString() {
    return 'FileRequestBody { file: $file, contentType: $contentType }';
  }
}
