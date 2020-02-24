import 'dart:math';

import 'package:restio/src/media_type.dart';
import 'package:restio/src/part.dart';
import 'package:restio/src/request_body.dart';

final _random = Random();

class MultipartBody implements RequestBody {
  final List<Part> parts;
  MediaType type;
  String _boundary;

  MultipartBody({
    this.parts = const [],
    this.type = MediaType.multipartMixed,
    String boundary,
  })  : assert(boundary == null || boundary.isNotEmpty),
        assert(type != null && type.type == 'multipart'),
        assert(parts != null) {
    _boundary = boundary ?? ('X-RESTIO-${_generateBoundary()}');
  }

  static String _generateBoundary() {
    return '${_random.nextInt(4294967296)}'.padLeft(10, '0');
  }

  @override
  Stream<List<int>> write() async* {
    final encoding = contentType.encoding;

    for (var i = 0; i < parts.length; i++) {
      yield* parts[i].write(encoding, boundary);
    }

    yield encoding.encode('\r\n--$boundary--\r\n');
  }

  @override
  MediaType get contentType => type.copyWith(boundary: _boundary);

  int get size => parts.length;

  String get boundary => _boundary;

  MultipartBody copyWith({
    List<Part> parts,
    MediaType type,
    String boundary,
  }) {
    return MultipartBody(
      parts: parts ?? this.parts,
      type: type ?? this.type,
      boundary: boundary ?? _boundary,
    );
  }

  @override
  String toString() {
    return 'MultipartBody { contentType: $contentType, parts: $parts }';
  }
}
