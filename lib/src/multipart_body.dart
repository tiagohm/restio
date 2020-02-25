import 'dart:convert';
import 'dart:math';

import 'package:restio/src/media_type.dart';
import 'package:restio/src/part.dart';
import 'package:restio/src/request_body.dart';

final _random = Random();

class MultipartBody implements RequestBody {
  final List<Part> parts;
  MediaType _contentType;
  String _boundary;

  MultipartBody({
    this.parts = const [],
    MediaType type = MediaType.multipartFormData,
    String boundary,
  })  : assert(boundary == null || boundary.isNotEmpty),
        assert(type != null && type.type == 'multipart'),
        assert(parts != null) {
    _boundary = boundary ?? ('X-RESTIO-${_generateBoundary()}');
    _contentType = type.copyWith(boundary: _boundary);
  }

  static String _generateBoundary() {
    return '${_random.nextInt(4294967296)}'.padLeft(10, '0');
  }

  @override
  Stream<List<int>> write() async* {
    final encoding = _contentType.encoding;

    for (var i = 0; i < parts.length; i++) {
      yield* parts[i].write(encoding, boundary);
    }

    yield utf8.encode('\r\n');
    yield utf8.encode('--');
    yield encoding.encode(boundary);
    yield utf8.encode('--');
    yield utf8.encode('\r\n');
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
      type: type ?? MediaType(
        type: _contentType.type,
        subType: _contentType.subType,
        charset: _contentType.charset,
        parameters: Map.of(_contentType.parameters)..remove('charset')..remove('boundary'),
      ),
      boundary: boundary ?? _boundary,
    );
  }

  @override
  String toString() {
    return 'MultipartBody { contentType: $_contentType, parts: $parts }';
  }
}
