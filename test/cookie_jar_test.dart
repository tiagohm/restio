import 'dart:io';

import 'package:restio/src/client.dart';
import 'package:restio/src/cookie_jar.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final client = Restio(
    cookieJar: _CookieJar(),
  );

  test('Send Cookies', () async {
    final request = Request(
      uri: Uri.parse('https://postman-echo.com/cookies'),
      method: 'GET',
    );

    final dynamic response = await requestJson(client, request);

    expect(response['cookies']['contador'], '1');
  });
}

class _CookieJar extends CookieJar {
  final _bucket = <Cookie>[];

  _CookieJar() {
    _bucket.add(Cookie('contador', '1'));
  }

  @override
  Future<List<Cookie>> loadForRequest(Request request) async {
    return _bucket;
  }

  @override
  Future<void> saveFromResponse(
    Response response,
    List<Cookie> cookies,
  ) async {
    for (final cookie in cookies) {
      // Busca o cookie por nome.
      final index = _bucket.indexWhere((item) => item.name == cookie.name);
      // Se já existe, substitui.
      if (index >= 0) {
        _bucket[index] = cookie;
      } else {
        _bucket.add(cookie);
      }
    }
  }
}
