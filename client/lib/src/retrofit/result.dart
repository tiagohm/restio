import 'dart:io';

import '../core/request/header/headers.dart';

class Result<T> {
  final T data;
  final Headers headers;
  final List<Cookie> cookies;
  final int code;
  final String message;

  const Result({
    this.data,
    this.headers = Headers.empty,
    this.cookies = const [],
    this.code = 0,
    this.message,
  });

  bool get hasData => data != null;

  bool get isSuccess => code != null && code >= 200 && code <= 299;

  bool get isError => code != null && code >= 400;
}
