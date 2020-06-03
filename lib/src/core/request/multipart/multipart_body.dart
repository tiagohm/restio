import 'dart:math';

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
    MediaType type = MediaType.multipartFormData,
    String boundary,
  })  : assert(boundary == null || boundary.isNotEmpty),
        assert(type != null && type.type == 'multipart'),
        assert(parts != null),
        contentLength = -1 {
    _boundary = boundary ?? _generateBoundary();
    _contentType = type.copyWith(boundary: _boundary);
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
    MediaType type,
    String boundary,
  }) {
    return MultipartBody(
      parts: parts ?? this.parts,
      type: type ??
          MediaType(
            type: _contentType.type,
            subType: _contentType.subType,
            parameters: Map.of(_contentType.parameters)
              ..remove('boundary'),
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
