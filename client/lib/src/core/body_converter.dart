import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/request/header/media_type.dart';

@immutable
class BodyConverter {
  const BodyConverter();

  Future<String> encode<T>(
    T value,
    MediaType contentType,
  ) async {
    final mimeType = contentType.mimeType;

    if (mimeType == 'application/json') {
      return json.encode(value);
    } else {
      throw RestioException('Content type $mimeType not supported');
    }
  }

  Future<T> decode<T>(
    String source,
    MediaType contentType,
  ) async {
    final mimeType = contentType.mimeType;

    if (mimeType == 'application/json') {
      return json.decode(source) as T;
    } else {
      throw RestioException('Content type $mimeType not supported');
    }
  }
}
