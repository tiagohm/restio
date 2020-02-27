import 'package:restio/src/request_uri.dart';
import 'package:test/test.dart';

void main() {
  test('Scheme', () {
    expect(parseUri('http://example.com')['scheme'], 'http');
    expect(parseUri('https://example.com')['scheme'], 'https');
    expect(parseUri('ftp://example.com')['scheme'], 'ftp');
    expect(parseUri('://example.com')['scheme'], isEmpty);
    expect(parseUri('{{scheme}}://example.com')['scheme'], '{{scheme}}');
  });

  test('Authority', () {
    var p = parseUri('http://user:pass@example.com');
    expect(p['username'], 'user');
    expect(p['password'], 'pass');
    expect(p['host'], 'example.com');
    expect(p['port'], isNull);

    p = parseUri('http://user@example.com');
    expect(p['username'], 'user');
    expect(p['password'], isNull);
    expect(p['host'], 'example.com');
    expect(p['port'], isNull);

    p = parseUri('http://:pass@example.com');
    expect(p['username'], '');
    expect(p['password'], 'pass');
    expect(p['host'], 'example.com');
    expect(p['port'], isNull);

    p = parseUri('http://example.com:8080');
    expect(p['username'], isNull);
    expect(p['password'], isNull);
    expect(p['host'], 'example.com');
    expect(p['port'], '8080');

    p = parseUri('{{scheme}}://{{user}}:{{pass}}@{{host}}:{{port}}');
    expect(p['username'], '{{user}}');
    expect(p['password'], '{{pass}}');
    expect(p['host'], '{{host}}');
    expect(p['port'], '{{port}}');
  });
}
