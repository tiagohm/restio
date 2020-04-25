import 'dart:io';

import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class CookieJar {
  Future<void> save(
    Response response,
    List<Cookie> cookies,
  );

  Future<List<Cookie>> load(Request request);
}
