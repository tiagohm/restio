import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final client = Restio(
    cookieJar: _CookieJar(),
  );

  test('Send Cookies', () async {
    final request = Request(
      uri: RequestUri.parse('https://postman-echo.com/cookies'),
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
  Future<List<Cookie>> load(Request request) async {
    return _bucket;
  }

  @override
  Future<void> save(Response response) async {
    for (final cookie in response.cookies) {
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
