import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

import 'httpbin.dart';

void main() {
  Restio client;
  HttpbinApi api;

  setUpAll(() {
    client = Restio();
    api = HttpbinApi(client: client);
  });

  group('Http Methods', () {
    test('Delete', () async {
      final data = await api.delete();
      expect(data['url'], 'https://httpbin.org/delete');
    });

    test('Get', () async {
      final data = await api.get();
      expect(data['url'], 'https://httpbin.org/get');
    });

    test('Patch', () async {
      final data = await api.patch();
      expect(data['url'], 'https://httpbin.org/patch');
    });

    test('Post', () async {
      final data = await api.post();
      expect(data['url'], 'https://httpbin.org/post');
    });

    test('Put', () async {
      final data = await api.put();
      expect(data['url'], 'https://httpbin.org/put');
    });
  });

  group('Auth', () {
    test('Basic', () async {
      var data = await api.basicAuth0('restio', '1234');
      expect(data['authenticated'], isTrue);
      expect(data['user'], 'restio');

      data = await api.basicAuth1();
      expect(data['authenticated'], isTrue);
      expect(data['user'], 'restio');
    });

    test('Bearer', () async {
      final data = await api.bearerAuth('Bearer 1234');
      expect(data['authenticated'], isTrue);
      expect(data['token'], '1234');
    });

    test('Digest', () async {
      const options = RequestOptions(
          auth: DigestAuthenticator(username: 'restio', password: '1234'));
      final data = await api.digestAuth('restio', '1234', options);
      expect(data['authenticated'], isTrue);
      expect(data['user'], 'restio');
    });
  });

  group('Status codes', () {
    test('200', () async {
      expect(await api.status(200), 200);
    });

    test('201', () async {
      expect(await api.status(201), 201);
    });

    test('400', () async {
      expectLater(api.badRequest, throwsA(isA<HttpStatusException>()));
    });

    test('Throws on 200 OK', () async {
      expectLater(api.throwsOnOk, throwsA(isA<HttpStatusException>()));
    });

    test('Throws on Redirect', () async {
      const options = RequestOptions(followRedirects: false);

      expectLater(
        () => api.throwsOnRedirect(options),
        throwsA(isA<HttpStatusException>()),
      );
    });

    test('Throws on Client Error', () async {
      expectLater(api.throwsOnClientError, throwsA(isA<HttpStatusException>()));
    });

    test('Throws on Server Error', () async {
      expectLater(api.throwsOnServerError, throwsA(isA<HttpStatusException>()));
    });

    test('Throws on Not 200 OK', () async {
      expectLater(api.throwsOnNotOk, throwsA(isA<HttpStatusException>()));
    });
  });

  group('Request Inspection', () {
    test('Headers', () async {
      final headers = Headers.fromMap({'g': 6});
      final data = await api.headers(
        '2',
        '3',
        {'e': 4, 'f': 5},
        headers,
        const [Header('h', '7')],
      );

      expect(data['headers']['A'], '0');
      expect(data['headers']['B'], '1');
      expect(data['headers']['C'], '2');
      expect(data['headers']['D'], '3');
      expect(data['headers']['E'], '4');
      expect(data['headers']['F'], '5');
      expect(data['headers']['G'], '6');
      expect(data['headers']['H'], '7');
    });

    test('Queries', () async {
      final queries = Queries.fromMap({'g': 6});
      final data = await api.queries(
        '2',
        '3',
        {'e': 4, 'f': 5},
        queries,
        const [Query('h', '7')],
        const ['i', 'j', 'k'],
      );

      expect(data['args']['a'], '0');
      expect(data['args']['b'], '1');
      expect(data['args']['c'], '2');
      expect(data['args']['D'], '3');
      expect(data['args']['e'], '4');
      expect(data['args']['f'], '5');
      expect(data['args']['g'], '6');
      expect(data['args']['h'], '7');
      expect(data['args']['i'], isEmpty);
      expect(data['args']['j'], isEmpty);
      expect(data['args']['k'], isEmpty);
      expect(data['args']['l'], '11');
    });

    test('Form', () async {
      final form = FormBody.fromMap({'g': 6});
      final data = await api.form(
        '2',
        '3',
        {'e': 4, 'f': 5},
        form,
        const [Field('h', '7')],
      );

      expect(data['form']['a'], '0');
      expect(data['form']['b'], '1');
      expect(data['form']['c'], '2');
      expect(data['form']['D'], '3');
      expect(data['form']['e'], '4');
      expect(data['form']['f'], '5');
      expect(data['form']['g'], '6');
      expect(data['form']['h'], '7');
    });

    test('Multipart', () async {
      final data = await api.multipart(
        '0',
        '1',
        File('./test/assets/text.txt'),
        Part.form('d', '3'),
        [
          Part.form('E', '4'),
          Part.file('f', 'e.txt', RequestBody.bytes([48, 49, 50])),
        ],
      );

      expect(data['form']['a'], '0');
      expect(data['form']['B'], '1');
      expect(data['form']['d'], '3');
      expect(data['form']['E'], '4');
      expect(data['files']['c'], 'a\nb\nc\n');
      expect(data['files']['f'], '012');
    });

    test('File Body', () async {
      final data = await api.fileBody(File('./test/assets/text.txt'));
      expect(data['data'], 'a\nb\nc\n');
      expect(data['headers']['Content-Type'], 'text/plain; charset=utf-8');
    });

    test('UTF-8 String Body', () async {
      final data = await api.utf8StringBody('🐨');
      expect(data['data'], '🐨');
      expect(data['headers']['Content-Type'], 'text/plain; charset=utf-8');
    });

    test('ASCII String Body', () async {
      final data = await api.asciiStringBody('Tiago');
      expect(data['data'], 'Tiago');
      expect(data['headers']['Content-Type'], 'text/plain; charset=ascii');
    });

    test('Bytes Body', () async {
      final data = await api.bytesBody(const [48, 49, 50]);
      expect(data['data'], '012');
      expect(data['headers']['Content-Type'], 'text/plain; charset=utf-8');
    });

    test('Stream Body', () async {
      final data = await api.streamBody(Stream.value(const [48, 49, 50]));
      expect(data['data'], '012');
      expect(data['headers']['Content-Type'], 'text/plain; charset=utf-8');
    });

    test('Gzip', () async {
      final data = await api.gzip();
      final raw = await api.raw();

      expect(data, isNotEmpty);
      expect(data, isNot(raw));
      expect(data.length, greaterThan(raw.length));
    });

    test('Json', () async {
      final data = await api.json();
      expect(data.author, 'Yours Truly');
      expect(data.title, 'Sample Slide Show');
      expect(data.date, 'date of publication');
    });
  });

  group('Misc', () {
    test('Extra', () async {
      final response = await api.extra({'id': 0});
      expect(response.code, 200);
      expect(response.originalRequest.extra['id'], 0);
      await response.close();
    });
  });

  tearDownAll(() async {
    await client.close();
  });
}
