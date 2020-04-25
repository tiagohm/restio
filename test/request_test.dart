import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

void main() {
  test('Query', () async {
    final req = Request(
      uri: RequestUri.parse('https://httpbin.org/get?a=b&c=d'),
      queries: Queries.fromMap(const {'e': 'f'}),
    );

    expect(req.uri.queries.length, 3);
    expect(req.queries.length, 3);

    final restio = Restio(cookieJar: _CookieJar());
    final call = restio.newCall(req);
    final response = await call.execute();

    final data = await response.body.data.json();

    expect(data['args']['a'], 'b');
    expect(data['args']['c'], 'd');
    expect(data['args']['e'], 'f');
  });
}

class _CookieJar extends CookieJar {
  @override
  Future<List<Cookie>> load(Request request) async {
    return const [];
  }

  @override
  Future<void> save(Response response, List<Cookie> cookies) async {}
}
