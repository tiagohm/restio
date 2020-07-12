import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/core/body_converter.dart';
import 'package:restio/src/core/client.dart';
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
    String charset,
  }) {
    final type = contentType ?? MediaType.octetStream;

    return _StreamRequestBody(
      data: data,
      contentType: charset != null ? type.copyWith(charset: charset) : type,
      contentLength: contentLength,
    );
  }

  factory RequestBody.bytes(
    List<int> data, {
    MediaType contentType,
    String charset,
  }) {
    final type = contentType ?? MediaType.octetStream;

    return _BytesRequestBody(
      data: data,
      contentType: charset != null ? type.copyWith(charset: charset) : type,
    );
  }

  factory RequestBody.string(
    String text, {
    MediaType contentType,
    int contentLength,
    String charset,
  }) {
    final type = contentType ?? MediaType.text;

    return _StringRequestBody(
      text: text,
      contentType: charset != null ? type.copyWith(charset: charset) : type,
      contentLength: contentLength,
    );
  }

  factory RequestBody.file(
    File file, {
    MediaType contentType,
    String charset,
    int start,
    int end,
  }) {
    return _FileRequestBody(
      file: file,
      contentType: contentType?.copyWith(charset: charset) ??
          MediaType.fromFile(file.path, charset: charset),
      start: start,
      end: end,
    );
  }

  /// Encodes [value] using [converter] or the default [Restio.bodyConverter].
  static RequestBody encode<T>(
    T value, {
    MediaType contentType,
    String charset,
    BodyConverter converter,
  }) {
    final type = contentType ?? MediaType.text;

    return _ConverterRequestBody<T>(
      value: value,
      converter: converter ?? Restio.bodyConverter,
      contentType: charset != null ? type.copyWith(charset: charset) : type,
    );
  }

  static const _prettyJson = JsonEncoder.withIndent('  ');

  /// Encodes [value] to JSON using [JsonEncoder].
  factory RequestBody.json(
    Object value, {
    bool pretty = false,
    String charset,
  }) {
    return RequestBody.string(
      pretty ? _prettyJson.convert(value) : jsonEncode(value),
      contentType: MediaType.json,
      charset: charset,
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

class _ConverterRequestBody<T> implements RequestBody {
  @override
  final MediaType contentType;
  @override
  final int contentLength;

  final T value;
  final BodyConverter converter;

  _ConverterRequestBody({
    @required this.value,
    @required this.converter,
    this.contentType,
    int contentLength,
  })  : assert(contentLength == null || contentLength >= -1),
        contentLength = contentLength ?? -1;

  @override
  Stream<List<int>> write() async* {
    final encoding = contentType?.encoding ?? utf8;
    yield encoding.encode(await converter.encode<T>(value, contentType));
  }

  @override
  String toString() {
    return 'ConverterRequestBody { contentType: $contentType,'
        ' contentLength: $contentLength, value: $value }';
  }
}
