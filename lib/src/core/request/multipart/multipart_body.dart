import 'dart:io';
import 'dart:math';

import 'package:path/path.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/multipart/part.dart';
import 'package:restio/src/core/request/request_body.dart';

final _random = Random();

class MultipartBody implements RequestBody {
  @override
  final int contentLength;
  final List<Part> parts;
  MediaType _contentType;
  String _boundary;

  MultipartBody({
    this.parts = const [],
    MediaType contentType,
    String boundary,
  })  : assert(boundary == null || boundary.isNotEmpty),
        assert(contentType == null || contentType.type == 'multipart'),
        assert(parts != null),
        _contentType = contentType ?? MediaType.multipartFormData,
        contentLength = -1 {
    _boundary = boundary ?? _generateBoundary();

    if (_boundary != null) {
      _contentType = _contentType.copyWith(boundary: _boundary);
    }
  }

  factory MultipartBody.fromMap(
    Map<String, dynamic> items, {
    MediaType contentType,
    String boundary,
  }) {
    final parts = <Part>[];

    void addPart(String key, final value) {
      if (value is Part) {
        parts.add(value);
      } else if (value is File) {
        final filename = basename(value.path);
        parts.add(Part.file(key, filename, RequestBody.file(value)));
      } else if (value is String || value is num || value is bool) {
        parts.add(Part.form(key, value.toString()));
      } else if (value is List) {
        for (final item in value) {
          addPart(key, item);
        }
      } else {
        throw ArgumentError('Unknown value type: ${value.runtimeType}');
      }
    }

    items?.forEach(addPart);

    return MultipartBody(
      parts: parts,
      contentType: contentType,
      boundary: boundary,
    );
  }

  static String _generateBoundary() {
    return 'X-RESTIO-' '${_random.nextInt(4294967296)}'.padLeft(10, '0');
  }

  @override
  Stream<List<int>> write() async* {
    final encoding = _contentType.encoding;

    for (var i = 0; i < parts.length; i++) {
      yield* parts[i].write(encoding, boundary);
    }

    yield encoding.encode('\r\n--$boundary--\r\n');
  }

  @override
  MediaType get contentType => _contentType;

  int get size => parts.length;

  String get boundary => _boundary;

  MultipartBody copyWith({
    List<Part> parts,
    MediaType contentType,
    String boundary,
  }) {
    return MultipartBody(
      parts: parts ?? this.parts,
      contentType: contentType ??
          MediaType(
            type: _contentType.type,
            subType: _contentType.subType,
            parameters: Map.of(_contentType.parameters)..remove('boundary'),
          ),
      boundary: boundary ?? _boundary,
    );
  }

  @override
  String toString() {
    return 'MultipartBody { contentType: $contentType,'
        ' boundary: $boundary, parts: $parts }';
  }
}
