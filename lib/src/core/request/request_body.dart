import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/core/request/header/media_type.dart';

abstract class RequestBody {
  MediaType get contentType;
  int get contentLength;

  Stream<List<int>> write();

  factory RequestBody.empty() => RequestBody.bytes(const []);

  factory RequestBody.stream(
    Stream<List<int>> data, {
    MediaType contentType,
    int contentLength,
  }) {
    return _StreamRequestBody(
      data: data,
      contentType: contentType ?? MediaType.octetStream,
      contentLength: contentLength,
    );
  }

  factory RequestBody.bytes(
    List<int> data, {
    MediaType contentType,
    int contentLength,
  }) {
    return _BytesRequestBody(
      data: data,
      contentType: contentType ?? MediaType.octetStream,
      contentLength: contentLength,
    );
  }

  factory RequestBody.string(
    String text, {
    MediaType contentType,
    int contentLength,
  }) {
    return _StringRequestBody(
      text: text,
      contentType: contentType ?? MediaType.text,
      contentLength: contentLength,
    );
  }

  factory RequestBody.file(
    File file, {
    MediaType contentType,
    int contentLength,
  }) {
    return _FileRequestBody(
      file: file,
      contentType: contentType ?? MediaType.fromFile(file.path),
      contentLength: contentLength,
    );
  }

  factory RequestBody.json(
    Object o, {
    bool pretty = false,
  }) {
    return RequestBody.string(
      pretty
          ? const JsonEncoder.withIndent('  ').convert(o)
          : json.encoder.convert(o),
      contentType: MediaType.json,
    );
  }
}

class _StreamRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  @override
  final int contentLength;
  final Stream<List<int>> data;

  _StreamRequestBody({
    @required this.data,
    this.contentType,
    int contentLength,
  })  : assert(data != null),
        assert(contentLength == null || contentLength >= -1),
        contentLength = contentLength ?? -1;

  @override
  Stream<List<int>> write() async* {
    yield* data;
  }

  @override
  String toString() {
    return 'StreamRequestBody { contentType: $contentType, contentLength: $contentLength }';
  }
}

class _StringRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  @override
  final int contentLength;
  final String text;

  _StringRequestBody({
    @required this.text,
    this.contentType,
    int contentLength,
  })  : assert(text != null),
        assert(contentLength == null || contentLength >= -1),
        contentLength = contentLength ?? -1;

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
    return 'StringRequestBody { text: $text, contentType: $contentType, contentLength: $contentLength }';
  }
}

class _BytesRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  @override
  final int contentLength;
  final List<int> data;

  _BytesRequestBody({
    @required this.data,
    this.contentType,
    int contentLength,
  })  : assert(data != null),
        assert(contentLength == null || contentLength > 0),
        contentLength = contentLength ?? data?.length ?? 0;

  @override
  Stream<List<int>> write() async* {
    yield data;
  }

  @override
  String toString() {
    return 'BytesRequestBody { data: $data, contentType: $contentType, contentLength: $contentLength }';
  }
}

class _FileRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  @override
  final int contentLength;
  final File file;

  _FileRequestBody({
    @required this.file,
    this.contentType,
    int contentLength,
  })  : assert(file != null),
        assert(contentLength == null || contentLength >= -1),
        contentLength = contentLength ?? file.lengthSync();

  @override
  Stream<List<int>> write() async* {
    yield await file.readAsBytes();
  }

  @override
  String toString() {
    return 'FileRequestBody { file: $file, contentType: $contentType, contentLength: $contentLength }';
  }
}
