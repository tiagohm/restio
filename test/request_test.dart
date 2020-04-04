import 'package:restio/restio.dart';
import 'package:restio/src/request.dart';
import 'package:test/test.dart';

void main() {
  test('Query', () {
    final req = Request(
      uri: RequestUri.parse('https://httpbin.org/get?a=b&c=d'),
      queries: Queries.fromMap(const {'e': 'f'}),
    );

    expect(req.uri.queries.length, 3);
    expect(req.queries.length, 3);
  });
}
