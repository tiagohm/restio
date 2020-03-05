import 'dart:io';

import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

class Redirect implements RedirectInfo {
  final Request request;
  final Response response;
  final int elapsedMilliseconds;

  const Redirect({
    this.request,
    this.response,
    this.elapsedMilliseconds,
  });

  @override
  int get statusCode => response.code;

  @override
  String get method => request.method;

  @override
  Uri get location => request.uri.toUri();

  @override
  String toString() {
    return 'Redirect { request: $request, response: $response, elapsedMilliseconds: $elapsedMilliseconds }';
  }
}
