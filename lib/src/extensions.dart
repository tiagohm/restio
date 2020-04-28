import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:restio/src/core/request/form/form_body.dart';
import 'package:restio/src/core/request/header/cache_control.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/multipart/multipart_body.dart';
import 'package:restio/src/core/request/multipart/part.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_body.dart';

// Request.

Request get(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  CacheControl cacheControl,
}) {
  return Request.get(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    cacheControl: cacheControl,
  );
}

Request post(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestBody body,
}) {
  return Request.post(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    body: body,
  );
}

Request put(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestBody body,
}) {
  return Request.put(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    body: body,
  );
}

Request delete(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestBody body,
}) {
  return Request.delete(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    body: body,
  );
}

Request head(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  CacheControl cacheControl,
}) {
  return Request.head(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    cacheControl: cacheControl,
  );
}

// Extensions.

extension StringExtension on String {
  RequestBody asBody([MediaType contentType]) {
    return RequestBody.string(this, contentType: contentType);
  }
}

extension FileExtension on File {
  RequestBody asBody([MediaType contentType]) {
    return RequestBody.file(this, contentType: contentType);
  }
}

extension MapExtension on Map<String, dynamic> {
  Queries asQueries() {
    return Queries.fromMap(this);
  }

  Headers asHeaders() {
    return Headers.fromMap(this);
  }

  FormBody asForm() {
    return FormBody.fromMap(this);
  }

  MultipartBody asMultipart() {
    final parts = <Part>[];

    void addPart(String key, final value) {
      if (value is Part) {
        parts.add(value);
      } else if (value is File) {
        final filename = path.basename(value.path);
        parts.add(Part.file(key, filename, value.asBody()));
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

    forEach(addPart);

    return MultipartBody(parts: parts);
  }
}

extension BytesExtension on List<int> {
  RequestBody asBody([MediaType contentType]) {
    return RequestBody.bytes(this, contentType: contentType);
  }
}
