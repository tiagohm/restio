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

  test('Username & Password', () {
    final p = parseUri('http://user:pass@example.com');
    expect(p['username'], 'user');
    expect(p['password'], 'pass');
  });

  test('Password is Optional', () {
    final p = parseUri('http://user@example.com');
    expect(p['username'], 'user');
    expect(p['password'], isNull);
  });

  test('Username Can be Optional?', () {
    final p = parseUri('http://:pass@example.com');
    expect(p['username'], isEmpty);
    expect(p['password'], 'pass');
  });

  test('Host', () {
    final p = parseUri('http://user:pass@example.com');
    expect(p['host'], 'example.com');
  });

  test('Port', () {
    final p = parseUri('http://user:pass@example.com:8080');
    expect(p['port'], '8080');
  });

  test('Path', () {
    var p = parseUri('http://user:pass@example.com:8080/a/b/c/d');
    expect(p['path'], const ['a', 'b', 'c', 'd']);

    p = parseUri('http://user:pass@example.com:8080');
    expect(p['path'], isEmpty);

    p = parseUri('http://user:pass@example.com:8080/');
    expect(p['path'], const ['']);

    p = parseUri('http://user:pass@example.com:8080//');
    expect(p['path'], const ['', '']);
  });

  test('Uri', () {
    final uri = Uri.parse('https://user:pass@example.com:8080/a/b/c?d=e#f');
    final req = RequestUri.fromUri(uri);
    expect(req.scheme, 'https');
    expect(req.username, 'user');
    expect(req.password, 'pass');
    expect(req.host, 'example.com');
    expect(req.port, '8080');
    expect(req.path, const ['a', 'b', 'c']);
    expect(req.query, const ['d', 'e']);
    expect(req.fragment, 'f');

    expect(req.toUri(), uri);
  });

  test('Https', () {
    final p = parseUri(
        'https://john.doe@www.example.com:123/forum/questions/?tag=networking&order=newest#top');
    expect(p['scheme'], 'https');
    expect(p['username'], 'john.doe');
    expect(p['password'], isNull);
    expect(p['host'], 'www.example.com');
    expect(p['port'], '123');
    expect(p['path'], const ['forum', 'questions', '']);
    expect(p['query'], const ['tag', 'networking', 'order', 'newest']);
    expect(p['fragment'], 'top');
  });

  test('Ldap', () {
    final p = parseUri('ldap://[2001:db8::7]/c=GB?objectClass=one');
    expect(p['scheme'], 'ldap');
    expect(p['username'], isNull);
    expect(p['password'], isNull);
    expect(p['host'], '[2001:db8::7]');
    expect(p['port'], isNull);
    expect(p['path'], const ['c=GB']);
    expect(p['query'], const ['objectClass', 'one']);
    expect(p['fragment'], isNull);
  });

  test('Mailto', () {
    final p = parseUri('mailto:John.Doe@example.com');
    expect(p['scheme'], 'mailto');
    expect(p['username'], isNull);
    expect(p['password'], isNull);
    expect(p['host'], isNull);
    expect(p['port'], isNull);
    expect(p['path'], const ['John.Doe@example.com']);
    expect(p['query'], isEmpty);
    expect(p['fragment'], isNull);
  });

  test('Tel', () {
    final p = parseUri('tel:+1-816-555-1212');
    expect(p['scheme'], 'tel');
    expect(p['username'], isNull);
    expect(p['password'], isNull);
    expect(p['host'], isNull);
    expect(p['port'], isNull);
    expect(p['path'], const ['+1-816-555-1212']);
    expect(p['query'], isEmpty);
    expect(p['fragment'], isNull);
  });

  test('To String', () {
    const uri = RequestUri(
      scheme: 'https',
      username: 'user',
      password: 'pass',
      host: 'example.com',
      port: '8080',
      path: ['a', 'b', 'c'],
      query: ['d', 'e', 'd', 'f'],
      fragment: 'g',
    );

    expect(
      uri.toString(),
      'https://user:pass@example.com:8080/a/b/c?d=e&d=f#g',
    );
  });
}
