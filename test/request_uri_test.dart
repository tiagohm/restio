import 'package:restio/src/queries.dart';
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

    p = parseUri('https://example.com/a/b');
    expect(p['path'], const ['a', 'b']);
  });

  test('Query', () {
    final uri = RequestUri.parse('https://httpbin.org/get?a=b&c=d');
    expect(uri.queries.length, 2);
    expect(uri.queries.nameAt(0), 'a');
    expect(uri.queries.valueAt(0), 'b');
    expect(uri.queries.nameAt(1), 'c');
    expect(uri.queries.valueAt(1), 'd');
  });

  test('Uri', () {
    final uri = Uri.parse('https://user:pass@example.com:8080/a/b/c?d=e#f');
    final req = RequestUri.fromUri(uri);
    expect(req.scheme, 'https');
    expect(req.username, 'user');
    expect(req.password, 'pass');
    expect(req.host, 'example.com');
    expect(req.port, '8080');
    expect(req.paths, const ['a', 'b', 'c']);
    expect(req.queries, Queries.fromMap({'d': 'e'}));
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
    final uri = RequestUri(
      scheme: 'https',
      username: 'user',
      password: 'pass',
      host: 'example.com',
      port: '8080',
      paths: const ['a', 'b', 'c'],
      queries: Queries.fromList(const ['d', 'e', 'd', 'f']),
      fragment: 'g',
    );

    expect(
      uri.toString(),
      'https://user:pass@example.com:8080/a/b/c?d=e&d=f#g',
    );
  });

  test('Path String', () {
    var uri = RequestUri.parse('https://example.com/a/b');
    expect(uri.paths, const ['a', 'b']);
    expect(uri.path, '/a/b');

    uri = RequestUri.parse('https://example.com/a/b/');
    expect(uri.path, '/a/b/');

    uri = RequestUri.parse('https://example.com/');
    expect(uri.path, '/');

    uri = RequestUri.parse('https://example.com');
    expect(uri.path, isEmpty);
  });
}
