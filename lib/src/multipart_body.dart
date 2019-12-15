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
    String boundary,
  })  : assert(boundary == null || boundary.isNotEmpty),
        assert(parts != null) {
    _boundary = boundary ?? ('X-RESTIO-${_generateBoundary()}');
    _contentType = MediaType.multipartFormData.copyWith(
      charset: 'utf-8',
      boundary: _boundary,
    );
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

    yield encoding.encode('\r\n--$boundary--\r\n');
  }

  @override
  MediaType get contentType => _contentType;

  int get size => parts.length;

  String get boundary => _boundary;

  MultipartBody copyWith({
    List<Part> parts,
    String boundary,
  }) {
    return MultipartBody(
      parts: parts ?? this.parts,
      boundary: boundary ?? _boundary,
    );
  }

  @override
  String toString() {
    return 'MultipartBody { contentType: $_contentType, parts: $parts }';
  }
}
