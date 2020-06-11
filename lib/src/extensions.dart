import 'dart:io';

import 'package:restio/src/core/request/form/form_body.dart';
import 'package:restio/src/core/request/header/cache_control.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/multipart/multipart_body.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_body.dart';
import 'package:restio/src/core/request/request_options.dart';

// Request.

Request get(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  CacheControl cacheControl,
  RequestOptions options,
  bool keepEqualSign = false,
}) {
  return Request.get(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    cacheControl: cacheControl,
    options: options,
    keepEqualSign: keepEqualSign,
  );
}

Request post(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestBody body,
  RequestOptions options,
  bool keepEqualSign = false,
}) {
  return Request.post(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    body: body,
    options: options,
    keepEqualSign: keepEqualSign,
  );
}

Request put(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestBody body,
  RequestOptions options,
  bool keepEqualSign = false,
}) {
  return Request.put(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    body: body,
    options: options,
    keepEqualSign: keepEqualSign,
  );
}

Request delete(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestBody body,
  RequestOptions options,
  bool keepEqualSign = false,
}) {
  return Request.delete(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    body: body,
    options: options,
    keepEqualSign: keepEqualSign,
  );
}

Request head(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  CacheControl cacheControl,
  RequestOptions options,
  bool keepEqualSign = false,
}) {
  return Request.head(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    cacheControl: cacheControl,
    options: options,
    keepEqualSign: keepEqualSign,
  );
}

Request patch(
  String uri, {
  Headers headers,
  Queries queries,
  Map<String, dynamic> extra,
  RequestOptions options,
  bool keepEqualSign = false,
}) {
  return Request.patch(
    uri,
    headers: headers,
    queries: queries,
    extra: extra,
    options: options,
    keepEqualSign: keepEqualSign,
  );
}

// Extensions.

extension StringExtension on String {
  RequestBody asBody([MediaType contentType]) {
    return RequestBody.string(this, contentType: contentType);
  }
}

extension FileExtension on File {
  RequestBody asBody({
    MediaType contentType,
    int start,
    int end,
  }) {
    return RequestBody.file(
      this,
      contentType: contentType,
      start: start,
      end: end,
    );
  }
}

extension MapExtension on Map<String, dynamic> {
  Queries asQueries({bool keepEqualSign = false}) {
    return Queries.fromMap(this, keepEqualSign: keepEqualSign);
  }

  Headers asHeaders() {
    return Headers.fromMap(this);
  }

  FormBody asForm() {
    return FormBody.fromMap(this);
  }

  MultipartBody asMultipart([MediaType contentType]) {
    return MultipartBody.fromMap(this, contentType: contentType);
  }
}

extension BytesExtension on List<int> {
  RequestBody asBody([MediaType contentType]) {
    return RequestBody.bytes(this, contentType: contentType);
  }
}
