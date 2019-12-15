import 'dart:io';

import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

class Redirect implements RedirectInfo {
  final Request request;
  final Response response;

  Redirect({
    this.request,
    this.response,
  });

  @override
  int get statusCode => response.code;

  @override
  String get method => request.method;

  @override
  Uri get location => request.uri;

  @override
  String toString() {
    return 'Redirect { request: $request, response: $response }';
  }
}
