import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/core/request/header/media_type.dart';

abstract class RequestBody {
  MediaType get contentType;
  int get contentLength;

  Stream<List<int>> write();

  factory RequestBody.empty() => const _EmptyRequestBody();

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
  }) {
    return _BytesRequestBody(
      data: data,
      contentType: contentType ?? MediaType.octetStream,
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
    String charset, // charset for auto-detect Content-Type.
    int start,
    int end,
  }) {
    return _FileRequestBody(
      file: file,
      contentType:
          contentType ?? MediaType.fromFile(file.path, charset: charset),
      start: start,
      end: end,
    );
  }

  static const _prettyJson = JsonEncoder.withIndent('  ');

  factory RequestBody.json(
    Object o, {
    bool pretty = false,
  }) {
    return RequestBody.string(
      pretty ? _prettyJson.convert(o) : json.encoder.convert(o),
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
    return 'StreamRequestBody { contentType: $contentType,'
        ' contentLength: $contentLength }';
  }
}

class _EmptyRequestBody implements RequestBody {
  @override
  final int contentLength = 0;
  @override
  final MediaType contentType = MediaType.octetStream;

  const _EmptyRequestBody();

  @override
  Stream<List<int>> write() async* {
    // nada.
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
    final encoding = contentType?.encoding ?? utf8;
    yield encoding.encode(text);
  }

  @override
  String toString() {
    return 'StringRequestBody { text: $text, contentType: $contentType,'
        ' contentLength: $contentLength }';
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
  })  : assert(data != null),
        contentLength = data?.length ?? 0;

  @override
  Stream<List<int>> write() async* {
    yield data;
  }

  @override
  String toString() {
    return 'BytesRequestBody { data: $data, contentType: $contentType,'
        ' contentLength: $contentLength }';
  }
}

class _FileRequestBody implements RequestBody {
  @override
  final MediaType contentType;
  @override
  final int contentLength;
  final File file;
  final int start;
  final int end;

  _FileRequestBody({
    @required this.file,
    this.contentType,
    this.start,
    this.end,
  })  : assert(file != null),
        contentLength = (end ?? file.lengthSync()) - (start ?? 0);

  @override
  Stream<List<int>> write() async* {
    yield* file.openRead(start ?? 0, end);
  }

  @override
  String toString() {
    return 'FileRequestBody { file: $file, contentType: $contentType,'
        ' contentLength: $contentLength }';
  }
}
