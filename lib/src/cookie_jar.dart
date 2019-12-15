import 'dart:io';

import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

abstract class CookieJar {
  const CookieJar();

  static const noCookies = _NoCookieJar();

  Future<void> saveFromResponse(
    Response response,
    List<Cookie> cookies,
  );

  Future<List<Cookie>> loadForRequest(Request request);
}

class _NoCookieJar extends CookieJar {
  const _NoCookieJar();

  @override
  Future<List<Cookie>> loadForRequest(Request request) async => const [];

  @override
  Future<void> saveFromResponse(
    Response response,
    List<Cookie> cookies,
  ) async {}
}
