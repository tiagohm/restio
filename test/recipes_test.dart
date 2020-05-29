import 'dart:async';
import 'dart:io';

import 'package:pubspec/pubspec.dart';
import 'package:restio/restio.dart';
import 'package:restio/src/core/interceptors/mock_interceptor.dart';
import 'package:restio/src/core/request/request_options.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final process = List<Process>(2);

  setUpAll(() async {
    process[0] = await Process.start('node', ['./test/node/ca/index.js']);
    process[1] = await Process.start('node', ['./test/node/proxy/index.js']);
    return Future.delayed(const Duration(seconds: 1));
  });

  tearDownAll(() {
    process[0]?.kill();
    process[1]?.kill();
  });

  test('Performing a GET request', () async {
    final client = Restio();
    final request = get('https://postman-echo.com/get');
    final call = client.newCall(request);
    final response = await call.execute();
    expect(response.code, 200);
    await response.close();
    await client.close();
  });

  test('Performing a POST request', () async {
    final client = Restio();
    final request = post(
      'https://postman-echo.com/post',
      body:
          'This is expected to be sent back as part of response body.'.asBody(),
    );
    final call = client.newCall(request);
    final response = await call.execute();
    expect(response.code, 200);
    final json = await response.body.json();
    await response.close();
    expect(json['headers']['content-length'], '58');
    expect(json['json'], null);
    await client.close();
  });

  test('Simple Get', () async {
    final client = Restio();
    final request = get('https://httpbin.org/json');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.body.contentType.type, 'application');
    expect(response.body.contentType.subType, 'json');
    expect(response.body.contentLength, 429);
    expect(response.code, 200);
    expect(response.isSuccess, true);
    expect(response.message, 'OK');

    await response.close();
    await client.close();
  });

  test('Cancelling a Call', () async {
    final client = Restio();
    final request = get('https://httpbin.org/delay/10');

    final call = client.newCall(request);
    Timer(const Duration(seconds: 5), () => call.cancel('Cancelado!'));

    expect(() async {
      final response = await call.execute();
      await response.close();
    }, throwsA(isA<CancelledException>()));

    await client.close();
  });

  test('Cancelling a HTTP2 Call', () async {
    final client = Restio(options: const RequestOptions(http2: true));
    final request = get('https://httpbin.org/delay/10');

    final call = client.newCall(request);
    Timer(const Duration(seconds: 5), () => call.cancel('Cancelado!'));

    expect(() async {
      final response = await call.execute();
      await response.close();
    }, throwsA(isA<CancelledException>()));

    await client.close();
  });

  test('Posting a String', () async {
    final client = Restio();
    final request = post(
      'https://postman-echo.com/post',
      body: 'Olá!'.asBody(),
      headers: {'content-type': 'application/json'}.asHeaders(),
    );

    final data = await requestJson(client, request);

    expect(data['data'], 'Olá!');
    expect(data['headers']['content-length'], '5');
    expect(data['headers']['content-type'], 'application/json');

    await client.close();
  });

  test('Posting Form Parameters', () async {
    final client = Restio();
    final request = post(
      'https://postman-echo.com/post',
      body: {'a': 'b', 'c': 'd'}.asForm(),
    );

    final data = await requestJson(client, request);

    expect(data['form']['a'], 'b');
    expect(data['form']['c'], 'd');

    await client.close();
  });

  test('Posting a Multipart Request', () async {
    final client = Restio();
    final request = post(
      'https://postman-echo.com/post',
      body: {
        'a': 'b',
        'c': 'd',
        'e': File('./test/assets/text.txt'),
      }.asMultipart(),
    );

    final data = await requestJson(client, request);

    expect(data['form']['a'], 'b');
    expect(data['form']['c'], 'd');
    expect(data['files']['text.txt'],
        'data:application/octet-stream;base64,YQpiCmMK');

    await client.close();
  });

  test('Posting Binary File', () async {
    var isDone = false;

    void onProgress(Request entity, int sent, int total, bool done) {
      print('sent: $sent, total: $total, done: $done');
      isDone = done;
    }

    final client = Restio(onUploadProgress: onProgress);

    final request = post(
      'https://postman-echo.com/post',
      body: File('./test/assets/binary.dat').asBody(),
    );

    final data = await requestJson(client, request);

    expect(isDone, true);
    expect(data['headers']['content-length'], '${request.body.contentLength}');
    expect(data['data']['type'], 'Buffer');
    expect(data['data']['data'], const [
      57, 142, 52, 40, 70, //
      185, 190, 43, 80, 153, //
    ]);

    await client.close();
  });

  test('Posting Binary File By HTTP2', () async {
    var isDone = false;

    void onProgress(Request entity, int sent, int total, bool done) {
      print('sent: $sent, total: $total, done: $done');
      isDone = done;
    }

    final client = Restio(
      onUploadProgress: onProgress,
      options: const RequestOptions(http2: true),
    );

    final request = post(
      'https://httpbin.org/post',
      body: File('./test/assets/binary.dat').asBody(),
    );

    final data = await requestJson(client, request);

    expect(isDone, true);
    expect(
        data['data'], 'data:application/octet-stream;base64,OY40KEa5vitQmQ==');

    await client.close();
  });

  test('Posting Part of Binary File', () async {
    final client = Restio();

    final request = post(
      'https://postman-echo.com/post',
      body: File('./test/assets/binary.dat').asBody(start: 2, end: 6),
    );

    final data = await requestJson(client, request);

    expect(data['headers']['content-length'], '${request.body.contentLength}');
    expect(data['data']['type'], 'Buffer');
    expect(data['data']['data'], const [52, 40, 70, 185]);

    await client.close();
  });

  test('User-Agent', () async {
    final client =
        Restio(options: const RequestOptions(userAgent: 'Restio (Dart)'));

    var request = get('https://postman-echo.com/get');
    var data = await requestJson(client, request);

    expect(data['headers']['user-agent'], 'Restio (Dart)');

    request = get(
      'https://postman-echo.com/get',
      headers: {HttpHeaders.userAgentHeader: 'jrit549ytyh549'}.asHeaders(),
    );

    data = await requestJson(client, request);

    expect(data['headers']['user-agent'], 'jrit549ytyh549');

    await client.close();
  });

  test('Posting a File', () async {
    final client = Restio();
    final request = post(
      'https://api.github.com/markdown/raw',
      body: '# Restio'.asBody(MediaType(type: 'text', subType: 'x-markdown')),
    );

    final data = await requestString(client, request);
    expect(data,
        '<h1>\n<a id="user-content-restio" class="anchor" href="#restio" aria-hidden="true"><span aria-hidden="true" class="octicon octicon-link"></span></a>Restio</h1>\n');

    await client.close();
  });

  test('Content-Type Auto Detect', () async {
    final client = Restio();
    final request = post(
      'https://httpbin.org/post',
      body: File('./test/assets/css.css').asBody(),
    );

    final data = await requestJson(client, request);
    expect(data['headers']['Content-Type'], 'text/css');

    await client.close();
  });

  test('Basic Auth', () async {
    final client = Restio(
      options: const RequestOptions(
        auth: BasicAuthenticator(
          username: 'a',
          password: 'b',
        ),
      ),
    );

    final request = get('https://httpbin.org/basic-auth/a/b');
    final response = await requestResponse(client, request);

    expect(response.code, 200);

    final data = await response.body.json();
    await response.close();
    expect(data['authenticated'], true);

    await client.close();
  });

  test('Bearer Auth', () async {
    final client = Restio();
    final authClient = client.copyWith(
      options: client.options.copyWith(
        auth: const BearerAuthenticator(
          token: '123',
        ),
      ),
    );

    final request = get('https://httpbin.org/bearer');

    final response = await requestResponse(authClient, request);
    expect(response.code, 200);

    final data = await response.body.json();
    await response.close();
    expect(data['authenticated'], true);
    expect(data['token'], '123');

    await client.close();
  });

  test('Digest Auth', () async {
    final client = Restio(
      options: const RequestOptions(
        auth: DigestAuthenticator(
          username: 'postman',
          password: 'password',
        ),
      ),
    );

    final request = get('https://postman-echo.com/digest-auth');

    final response = await requestResponse(client, request);
    expect(response.code, 200);

    final data = await response.body.json();
    await response.close();
    expect(data['authenticated'], true);

    await client.close();
  });

  test('Hawk Auth', () async {
    final client = Restio(
      options: const RequestOptions(
        auth: HawkAuthenticator(
          id: 'dh37fgj492je',
          key: 'werxhqb98rpaxn39848xrunpaw3489ruxnpa98w4rxn',
        ),
      ),
    );

    final request = get('https://postman-echo.com/auth/hawk');

    final response = await requestResponse(client, request);
    expect(response.code, 200);

    final data = await response.body.json();
    await response.close();
    expect(data['message'], 'Hawk Authentication Successful');

    await client.close();
  });

  test('Queries Should Be Included In the Hawk Auth Resource', () async {
    final client = Restio(
      options: const RequestOptions(
        auth: HawkAuthenticator(
          id: 'dh37fgj492je',
          key: 'werxhqb98rpaxn39848xrunpaw3489ruxnpa98w4rxn',
        ),
      ),
    );

    var request = get('https://postman-echo.com/auth/hawk?a=b');
    var response = await requestResponse(client, request);
    expect(response.code, 200);

    request = get('https://postman-echo.com/auth/hawk/?a=b');
    response = await requestResponse(client, request);
    expect(response.code, 200);

    request = get('https://postman-echo.com/auth/hawk?a=', keepEqualSign: true);
    response = await requestResponse(client, request);
    expect(response.code, 200);

    request = get('https://postman-echo.com/auth/hawk?a');
    response = await requestResponse(client, request);
    expect(response.code, 200);

    await client.close();
  });

  test('Timeout', () async {
    final client = Restio(
      options: const RequestOptions(
        connectTimeout: Duration(seconds: 2),
        writeTimeout: Duration(seconds: 2),
        receiveTimeout: Duration(seconds: 2),
      ),
    );

    final request = get('https://httpbin.org/delay/10');

    final call = client.newCall(request);

    try {
      final response = await call.execute();
      await response.close();
    } on TimedOutException catch (e) {
      expect(e.message, '');
    }

    await client.close();
  });

  test('Queries', () async {
    final client = Restio();
    final request = get(
      'https://api.github.com/search/repositories?q=flutter&sort=stars',
      queries: {'order': 'desc', 'per_page': '2'}.asQueries(),
    );

    expect(request.queries.value('q'), 'flutter');
    expect(request.queries.value('sort'), 'stars');
    expect(request.queries.value('order'), 'desc');
    expect(request.queries.value('per_page'), '2');

    final response = await requestResponse(client, request);
    expect(response.code, 200);

    final data = await response.body.json();
    await response.close();
    expect(data['items'].length, 2);
    expect(data['items'][0]['full_name'], 'flutter/flutter');

    await client.close();
  });

  test('Raw Data', () async {
    final client = Restio();
    final request = get('https://httpbin.org/robots.txt');

    final call = client.newCall(request);
    final response = await call.execute();
    final data = await response.body.raw();
    await response.close();

    expect(data.length, 30);

    await client.close();
  });

  test('Gzip', () async {
    final client = Restio();
    final request = get('https://httpbin.org/gzip');
    final data = await requestJson(client, request);
    expect(data['gzipped'], true);
    await client.close();
  });

  test('Deflate', () async {
    final client = Restio();
    final request = get('https://httpbin.org/deflate');
    final data = await requestJson(client, request);
    expect(data['deflated'], true);
    await client.close();
  });

  test('Brotli', () async {
    final client = Restio();
    final request = get('https://httpbin.org/brotli');
    final data = await requestJson(client, request);
    expect(data['brotli'], true);
    await client.close();
  });

  group('Redirects', () {
    test('Absolute redirects n times', () async {
      final client = Restio(options: const RequestOptions(maxRedirects: 9));
      final request = get('https://httpbin.org/absolute-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);

      await response.close();
      await client.close();
    });

    test('Relative redirects n times', () async {
      final client = Restio(options: const RequestOptions(maxRedirects: 9));
      final request = get('https://httpbin.org/relative-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);
      expect(response.redirects[6].request.uri.path, '/get');

      await response.close();
      await client.close();
    });

    test('Too many redirects exception', () async {
      final client = Restio(options: const RequestOptions(maxRedirects: 9));
      final request = get('https://httpbin.org/absolute-redirect/10');
      final call = client.newCall(request);

      try {
        final response = await call.execute();
        await response.close();
        expect(true, false);
      } on TooManyRedirectsException catch (e) {
        expect(e.message, 'Too many redirects: 10');
        expect(e.uri.toUriString(), 'https://httpbin.org/absolute-redirect/10');
      }

      await client.close();
    });
  });

  group('Redirects with DNS', () {
    test('Absolute redirects n times', () async {
      final client = Restio(
        options: RequestOptions(maxRedirects: 9, dns: DnsOverUdp.google()),
      );
      final request = get('https://httpbin.org/absolute-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);

      await response.close();
      await client.close();
    });

    test('Relative redirects n times', () async {
      final client = Restio(
        options: RequestOptions(maxRedirects: 9, dns: DnsOverUdp.google()),
      );
      final request = get('https://httpbin.org/relative-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);
      expect(response.redirects[6].request.uri.path, '/get');

      await response.close();
      await client.close();
    });

    test('Too many redirects exception', () async {
      final client = Restio(
        options: RequestOptions(maxRedirects: 9, dns: DnsOverUdp.google()),
      );
      final request = get('https://httpbin.org/absolute-redirect/10');
      final call = client.newCall(request);

      try {
        final response = await call.execute();
        await response.close();
        expect(true, false);
      } on TooManyRedirectsException catch (e) {
        expect(e.message, 'Too many redirects: 10');
        expect(e.uri.toUriString(), 'https://httpbin.org/absolute-redirect/10');
      }

      await client.close();
    });
  });

  test('Chunked', () async {
    final client = Restio();
    var isDone = false;

    void onProgress(Response entity, int rcv, int total, bool done) {
      final pc = total / entity.headers.contentLength * 100;
      print('received: $rcv, total: $total, done: $done, %: $pc');
      isDone = done;
    }

    final progressClient = client.copyWith(
      onDownloadProgress: onProgress,
    );

    final request = get('https://httpbin.org/stream-bytes/36001');

    final call = progressClient.newCall(request);
    final response = await call.execute();
    final data = await response.body.raw();

    expect(data.length, 36001);
    expect(isDone, true);

    await response.close();
    await client.close();
  });

  test('Pause & Resume', () async {
    final client = Restio();
    final startTime = DateTime.now().millisecondsSinceEpoch;
    Response response;

    void onProgress(Response entity, int rcv, int total, bool done) async {
      print('received: $rcv, total: $total, done: $done');

      if (total > 18000 && total < 19000) {
        print('paused');
        response.body.pause();
        Timer(const Duration(seconds: 5), response.body.resume);
      }
    }

    final progressClient = client.copyWith(
      onDownloadProgress: onProgress,
    );

    final request = get('https://httpbin.org/stream-bytes/36001');

    final call = progressClient.newCall(request);
    response = await call.execute();
    final raw = await response.body.raw();
    await response.close();

    final endTime = DateTime.now().millisecondsSinceEpoch;

    expect(raw.length, isNonZero);
    expect(endTime - startTime, greaterThan(5000));
    await client.close();
  });

  test('Retry after', () async {
    final client = Restio();
    final retryAfterClient = client.copyWith(networkInterceptors: [
      _RetryAfterInterceptor(15),
    ]);

    final request = get('https://httpbin.org/absolute-redirect/1');
    final call = retryAfterClient.newCall(request);
    final response = await call.execute();
    await response.close();
    expect(response.totalMilliseconds, greaterThan(15000));
    await client.close();
  });

  test('HTTP2', () async {
    final client = Restio(options: const RequestOptions(http2: true));

    final request = get('https://http2.pro/api/v1');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    expect(json['http2'], 1);
    expect(json['protocol'], 'HTTP/2.0');
    expect(json['push'], 0);
    expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'br');

    await client.close();
  });

  test('HTTP2 Server Push Is Enabled', () async {
    final client = Restio(
        options: const RequestOptions(
      http2: true,
      allowServerPushes: true,
    ));

    final request = get('https://http2.pro/api/v1');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    expect(json['http2'], 1);
    expect(json['protocol'], 'HTTP/2.0');
    expect(json['push'], 1);
    expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'br');
    await client.close();
  });

  test('HTTP2 Server Push', () async {
    final client = Restio(
        options: const RequestOptions(
      http2: true,
      allowServerPushes: true,
    ));

    final request = get('https://nghttp2.org/');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final body = await response.body.string();
    final pushPaths = <String>[];
    final futures = <Future<Response>>[];

    await response.pushes.listen((push) async {
      futures.add(push.response.then(
        (response) {
          pushPaths.add(push.headers.first(':path')?.value);
          return response;
        },
      ));
    }).asFuture();

    expect(body, contains('<!DOCTYPE html>'));
    expect(body, contains('nghttp2'));

    expect(pushPaths, isNotEmpty);
    expect(pushPaths[0], '/stylesheets/screen.css');
    expect(futures, isNotEmpty);
    expect(await (await futures[0]).body.string(), contains('audio,video{'));

    await response.close();

    await client.close();
  });

  test('HTTP2 Server Push Is Disabled', () async {
    final client = Restio(
        options: const RequestOptions(
      http2: true,
      allowServerPushes: false,
    ));

    final request = get('https://nghttp2.org/');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final body = await response.body.string();
    final pushPaths = <String>[];
    final futures = <Future<Response>>[];

    await response.pushes.listen((push) {
      futures.add(push.response.then(
        (response) {
          pushPaths.add(push.headers.first(':path')?.value);
          return response;
        },
      ));
    }).asFuture();

    expect(body, contains('<!DOCTYPE html>'));
    expect(body, contains('nghttp2'));

    expect(pushPaths, isEmpty);
    expect(futures, isEmpty);

    await response.close();

    await client.close();
  });

  test('Client Certificate', () async {
    final client = Restio(
      certificates: [
        Certificate(
          host: 'client.badssl.com',
          certificate:
              File('./test/assets/badssl.com-client.pem').readAsBytesSync(),
          privateKey:
              File('./test/assets/badssl.com-client.p12').readAsBytesSync(),
          port: 443,
          password: 'badssl.com',
        ),
      ],
    );
    final request = get('https://client.badssl.com/');
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);

    await client.close();
  });

  test('Proxy', () async {
    final client = Restio(
      options: const RequestOptions(
        proxy: Proxy(
          host: 'localhost',
          port: 3004,
        ),
        auth: BasicAuthenticator(
          username: 'c',
          password: 'd',
        ),
      ),
    );

    final request = get('http://httpbin.org/basic-auth/c/d');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    print(json);

    expect(json['authenticated'], true);
    expect(json['user'], 'c');

    await client.close();
  });

  test('Auth Proxy', () async {
    final client = Restio(
      options: const RequestOptions(
        proxy: Proxy(
          host: 'localhost',
          port: 3005,
          auth: BasicAuthenticator(
            username: 'a',
            password: 'b',
          ),
        ),
        auth: BasicAuthenticator(
          username: 'c',
          password: 'd',
        ),
      ),
    );

    final request = get('http://httpbin.org/basic-auth/c/d');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    expect(json['authenticated'], true);

    await client.close();
  });

  test('DNS-Over-UDP', () async {
    final dns = DnsOverUdp.google();
    final client = Restio(options: RequestOptions(dns: dns));
    final request = get('https://httpbin.org/get?a=b');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    expect(json['url'], 'https://httpbin.org/get?a=b');
    expect(json['args']['a'], 'b');
    expect(response.address, isNotNull);

    await client.close();
  });

  test('DNS-Over-HTTPS', () async {
    final dns = DnsOverUdp.google();
    final client = Restio(options: RequestOptions(dns: dns));
    final request = get('https://httpbin.org/get?a=b');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    expect(json['url'], 'https://httpbin.org/get?a=b');
    expect(json['args']['a'], 'b');
    expect(response.address, isNotNull);

    await client.close();
  });

  test('Custom Host Header', () async {
    final dns = DnsOverHttps.google();
    final client = Restio(options: RequestOptions(dns: dns));

    final request = get(
      'https://httpbin.org/get',
      headers: {'Host': 'google.com'}.asHeaders(),
    );
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.json();
    await response.close();

    expect(json['url'], 'https://google.com/get');

    await client.close();
  });

  test('Force Accept-Encoding', () async {
    final client = Restio(options: const RequestOptions(http2: true));

    final request = get(
      'https://http2.pro/api/v1',
      headers: {HttpHeaders.acceptEncodingHeader: 'gzip'}.asHeaders(),
    );
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);
    expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');

    await client.close();
  });

  test('Fix DNS timeout bug', () async {
    final dns = DnsOverUdp.ip('1.1.1.1');
    final client = Restio(options: RequestOptions(dns: dns));

    final request = get('https://httpbin.org/absolute-redirect/5');
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);

    await client.close();
  });

  test('Cookies', () async {
    final client = Restio();
    final request = get('https://postman-echo.com/get');
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);
    expect(response.cookies.length, 1);
    expect(response.cookies[0].name, 'sails.sid');

    await client.close();
  });

  test('Version', () async {
    final client = Restio();
    final request = get('https://httpbin.org/get');
    final call = client.newCall(request);
    final response = await call.execute();
    final json = await response.body.json();
    await response.close();

    print(json);

    final pubSpec = await PubSpec.load(Directory('.'));

    expect(response.code, 200);
    expect(json['headers']['User-Agent'], 'Restio/${pubSpec.version}');

    await client.close();
  });

  test('Cache', () async {
    final cacheStore = await LruCacheStore.local('./.cache');
    final cache = Cache(store: cacheStore);
    await cache.clear();

    final client = Restio(cache: cache);

    // cache-control: private, max-age=60
    var request = get('http://www.mocky.io/v2/5e230fa42f00009a00222692');

    var call = client.newCall(request);
    var response = await call.execute();
    var text = await response.body.string();
    expect(text, 'Restio Caching test!');
    await response.close();

    expect(response.code, 200);
    expect(response.spentMilliseconds, isNonZero);
    expect(response.totalMilliseconds, isNonZero);
    expect(response.networkResponse, isNotNull);
    expect(response.networkResponse.spentMilliseconds, isNonZero);
    expect(response.networkResponse.totalMilliseconds, isNonZero);
    expect(response.totalMilliseconds,
        greaterThanOrEqualTo(response.networkResponse.totalMilliseconds));
    expect(response.cacheResponse, isNull);

    response = await call.execute();
    text = await response.body.string();
    await response.close();

    expect(text, 'Restio Caching test!');
    expect(response.code, 200);
    expect(response.spentMilliseconds, isZero);
    expect(response.totalMilliseconds, isZero);
    expect(response.networkResponse, isNull);
    expect(response.cacheResponse, isNotNull);

    request = request.copyWith(cacheControl: CacheControl.forceCache);

    call = client.newCall(request);
    response = await call.execute();
    text = await response.body.string();
    expect(text, 'Restio Caching test!');
    await response.close();

    expect(response.code, 200);
    expect(response.spentMilliseconds, isZero);
    expect(response.totalMilliseconds, isZero);
    expect(response.networkResponse, isNull);
    expect(response.cacheResponse, isNotNull);

    await cache.clear();

    response = await call.execute();
    text = await response.body.string();
    await response.close();

    expect(response.code, 504);
    expect(response.cacheResponse, isNull);

    request = request.copyWith(cacheControl: CacheControl.forceNetwork);

    call = client.newCall(request);
    response = await call.execute();
    text = await response.body.string();
    expect(text, 'Restio Caching test!');
    await response.close();

    expect(response.code, 200);
    expect(response.spentMilliseconds, isNonZero);
    expect(response.totalMilliseconds, isNonZero);
    expect(response.networkResponse, isNotNull);
    expect(response.networkResponse.spentMilliseconds, isNonZero);
    expect(response.networkResponse.totalMilliseconds, isNonZero);
    expect(response.totalMilliseconds,
        greaterThanOrEqualTo(response.networkResponse.totalMilliseconds));
    expect(response.cacheResponse, isNull);

    response = await call.execute();
    text = await response.body.string();
    expect(text, 'Restio Caching test!');
    await response.close();

    expect(response.code, 200);
    expect(response.spentMilliseconds, isNonZero);
    expect(response.totalMilliseconds, isNonZero);
    expect(response.networkResponse, isNotNull);
    expect(response.cacheResponse, isNull);

    await client.close();
  });

  test('Empty Cache-Control Value', () async {
    final client = Restio();
    final request = get(
      'https://httpbin.org/get',
      headers: {'cache-control': ''}.asHeaders(),
    );
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);

    await client.close();
  });

  test('Encoded Form Body', () async {
    final client = Restio();
    final body = (FormBuilder()
          ..add(" \"':;<=>+@[]^`{}|/\\?#&!\$(),~",
              " \"':;<=>+@[]^`{}|/\\?#&!\$(),~")
          ..add('円', '円')
          ..add('£', '£')
          ..add('text', 'text'))
        .build();

    final request = post(
      'https://httpbin.org/post',
      body: body,
    );

    final call = client.newCall(request);
    final response = await call.execute();

    final json = await response.body.json();

    await response.close();

    expect(response.code, 200);

    expect(json['form'][" \"':;<=>+@[]^`{}|/\\?#&!\$(),~"],
        " \"':;<=>+@[]^`{}|/\\?#&!\$(),~");
    expect(json['form']['円'], '円');
    expect(json['form']['£'], '£');
    expect(json['form']['text'], 'text');

    await client.close();
  });

  test('Fix Default JSON Encoding', () async {
    final client = Restio();
    final request = get('http://www.mocky.io/v2/5e2d86473000005000e77d19');
    final call = client.newCall(request);
    final response = await call.execute();
    final json = await response.body.json();
    await response.close();

    expect(response.code, 200);

    expect(json, 'este é um corpo UTF-8');

    await client.close();
  });

  test('Fix Timestamp When Use Cache', () async {
    final store = await LruCacheStore.memory();
    final cacheClient = Restio(cache: Cache(store: store));
    final request = get('https://httpbin.org/redirect/5');
    final call = cacheClient.newCall(request);
    final response = await call.execute();
    await response.body.json();
    await response.close();

    expect(response.code, 200);
    expect(response.redirects.length, 5);
    expect(response.totalMilliseconds,
        greaterThanOrEqualTo(response.redirects.last.elapsedMilliseconds));

    await cacheClient.close();
  });

  test('Redirect Policy', () async {
    var client = Restio(
      redirectPolicies: [
        const DomainCheckRedirectPolicy(['goo.gle', 'www.blog.google']),
      ],
    );

    final request = Request.get('https://t.co/fsjV0tgRSa');
    var response = await requestResponse(client, request);

    expect(response.code, 200);
    expect(response.redirects.last.request.uri.host, 'www.blog.google');

    client = client.copyWith(
      redirectPolicies: const [
        DomainCheckRedirectPolicy(['goo.gle']),
      ],
    );

    response = await requestResponse(client, request);

    expect(response.code, 301);
    expect(response.redirects.last.request.uri.host, 'goo.gle');

    await client.close();
  });

  test('Fix Bug #16', () async {
    final client = Restio(
      options: const RequestOptions(
        http2: true,
        receiveTimeout: Duration(seconds: 4),
        connectTimeout: Duration(seconds: 4),
        writeTimeout: Duration(seconds: 4),
      ),
    );

    final request = Request.get('https://httpbin.org/delay/10');
    final call = client.newCall(request);

    expect(() async => await call.execute(), throwsA(isA<TimedOutException>()));

    await client.close();
  });

  test('Call can be executed multiple times', () async {
    final client = Restio();

    final request = Request.get('https://httpbin.org/get');
    final call = client.newCall(request);

    final response1 = await call.execute();
    final response2 = await call.execute();

    final data1 = await response1.body.json();
    final data2 = await response2.body.json();

    final header1 = data1['headers']['X-Amzn-Trace-Id'];
    final header2 = data2['headers']['X-Amzn-Trace-Id'];

    expect(response1.code, 200);
    expect(response2.code, 200);
    expect(header1, isNot(header2));

    await client.close();
  });

  test('Persistent Connection', () async {
    final client = Restio();

    final request = Request.get('https://httpbin.org/get');
    final call = client.newCall(request);

    final response1 = await call.execute();
    print(await response1.body.json());
    await response1.close();

    final response2 = await call.execute();
    print(await response2.body.json());
    await response2.close();

    expect(
      response1.localPort,
      response2.localPort,
    );

    await client.close();
  });

  test('HTTP2 Persistent Connection', () async {
    final client = Restio(options: const RequestOptions(http2: true));

    final request = Request.get('https://httpbin.org/get');
    final call = client.newCall(request);

    final response1 = await call.execute();
    print(await response1.body.json());
    await response1.close();

    final response2 = await call.execute();
    print(await response2.body.json());
    await response2.close();

    expect(
      response1.localPort,
      response2.localPort,
    );

    await client.close();
  });

  test('Persistent Connection With Short Timeout', () async {
    final client = Restio(
      httpConnectionPool:
          HttpConnectionPool(idleTimeout: const Duration(seconds: 5)),
    );

    final request = Request.get('https://httpbin.org/delay/10');
    final call = client.newCall(request);

    final response1 = await call.execute();
    print(await response1.body.json());
    await response1.close();

    await Future.delayed(const Duration(seconds: 6));

    final response2 = await call.execute();
    print(await response2.body.json());
    await response2.close();

    expect(
      response1.localPort,
      isNot(response2.localPort),
    );

    await client.close();
  });

  test('HTTP2 Persistent Connection With Short Timeout', () async {
    final client = Restio(
      options: const RequestOptions(http2: true),
      http2ConnectionPool:
          Http2ConnectionPool(idleTimeout: const Duration(seconds: 5)),
    );

    final request = Request.get('https://httpbin.org/delay/10');
    final call = client.newCall(request);

    final response1 = await call.execute();
    print(await response1.body.json());
    await response1.close();

    await Future.delayed(const Duration(seconds: 6));

    final response2 = await call.execute();
    print(await response2.body.json());
    await response2.close();

    expect(
      response1.localPort,
      isNot(response2.localPort),
    );

    await client.close();
  });

  test('Not Persist Connection For Two Schemes', () async {
    final client = Restio();

    var request = Request.get('https://httpbin.org/get');
    var call = client.newCall(request);

    final response1 = await call.execute();
    print(await response1.body.json());
    await response1.close();

    request = Request.get('http://httpbin.org/get');
    call = client.newCall(request);
    final response2 = await call.execute();
    print(await response2.body.json());
    await response2.close();

    expect(
      response1.localPort,
      isNot(response2.localPort),
    );

    await client.close();
  });

  test('Two Call Share Same Connection', () async {
    final client = Restio();

    final request = Request.get('https://httpbin.org/get');
    var call = client.newCall(request);

    final response1 = await call.execute();
    print(await response1.body.json());
    await response1.close();

    call = client.newCall(request);
    final response2 = await call.execute();
    print(await response2.body.json());
    await response2.close();

    expect(
      response1.localPort,
      response2.localPort,
    );

    await client.close();
  });

  group('Request Options', () {
    test('Authentication', () async {
      final client = Restio(
        options: const RequestOptions(
          auth: BasicAuthenticator(username: 'c', password: 'd'),
        ),
      );

      const options = RequestOptions(
        auth: BasicAuthenticator(username: 'a', password: 'b'),
      );

      final request =
          get('https://httpbin.org/basic-auth/a/b', options: options);
      final response = await requestResponse(client, request);

      expect(response.code, 200);

      final data = await response.body.json();
      await response.close();

      expect(data['authenticated'], true);

      await client.close();
    });

    test('Follow Redirects', () async {
      final client = Restio(
        options: const RequestOptions(followRedirects: true),
      );

      const options = RequestOptions(followRedirects: false);
      final request = get('https://httpbin.org/redirect/1', options: options);
      final response = await requestResponse(client, request);
      await response.close();

      expect(response.code, 302);

      await client.close();
    });

    test('Too many redirects exception', () async {
      final client = Restio(
        options: const RequestOptions(maxRedirects: 200),
      );

      const options = RequestOptions(maxRedirects: 2);
      final request = get('https://httpbin.org/redirect/5', options: options);

      final call = client.newCall(request);

      try {
        final response = await call.execute();
        await response.close();
        expect(true, false);
      } on TooManyRedirectsException catch (e) {
        expect(e.message, 'Too many redirects: 3');
        expect(e.uri.toUriString(), 'https://httpbin.org/redirect/5');
      }

      await client.close();
    });

    test('User-Agent', () async {
      final client = Restio(
        options: const RequestOptions(userAgent: 'pqrstuvwxyz'),
      );

      const options = RequestOptions(userAgent: 'abcdefghijklmno');
      final request = get('https://postman-echo.com/get', options: options);
      final data = await requestJson(client, request);

      expect(data['headers']['user-agent'], 'abcdefghijklmno');

      await client.close();
    });

    test('DNS', () async {
      final client = Restio();
      final options = RequestOptions(dns: DnsOverHttps.google());
      final request = get('https://postman-echo.com/get', options: options);
      final response = await requestResponse(client, request);

      expect(response.address, isNotNull);
    });

    test('Authentication via HTTP2', () async {
      final client = Restio(
        options: const RequestOptions(
          auth: BasicAuthenticator(username: 'c', password: 'd'),
        ),
      );

      const options = RequestOptions(
        auth: BasicAuthenticator(username: 'a', password: 'b'),
      );

      final request =
          get('https://httpbin.org/basic-auth/a/b', options: options);
      final response = await requestResponse(
          client.copyWith(options: client.options.copyWith(http2: true)),
          request);

      expect(response.code, 200);

      final data = await response.body.json();
      await response.close();

      expect(data['authenticated'], true);

      await client.close();
    });

    test('Equal Sign If Empty', () async {
      final client = Restio();

      var request = get('https://httpbin.org/get?a=', keepEqualSign: true);
      var response = await requestResponse(client, request);
      var data = await response.body.json();
      await response.close();
      expect(data['url'], 'https://httpbin.org/get?a=');

      request = get('https://httpbin.org/get?a', keepEqualSign: true);
      response = await requestResponse(client, request);
      data = await response.body.json();
      await response.close();
      expect(data['url'], 'https://httpbin.org/get?a=');

      request = get('https://httpbin.org/get?a=');
      response = await requestResponse(client, request);
      data = await response.body.json();
      await response.close();
      expect(data['url'], 'https://httpbin.org/get?a');

      request = get('https://httpbin.org/get?a');
      response = await requestResponse(client, request);
      data = await response.body.json();
      await response.close();
      expect(data['url'], 'https://httpbin.org/get?a');

      request = get('https://httpbin.org/get?a',
          queries: {'c': 'd'}.asQueries(keepEqualSign: true));
      response = await requestResponse(client, request);
      data = await response.body.json();
      await response.close();
      expect(data['url'], 'https://httpbin.org/get?a=&c=d');

      await client.close();
    });

    test('Client Certificate', () async {
      final certificate = Certificate(
        host: 'client.badssl.com',
        certificate:
            File('./test/assets/badssl.com-client.pem').readAsBytesSync(),
        privateKey:
            File('./test/assets/badssl.com-client.p12').readAsBytesSync(),
        port: 443,
        password: 'badssl.com',
      );
      final client = Restio();
      final request = get('https://client.badssl.com/',
          options: RequestOptions(certificate: certificate));
      final call = client.newCall(request);
      final response = await call.execute();
      await response.close();

      expect(response.code, 200);
    });
  });

  test('Mocking', () async {
    final client = Restio(
      networkInterceptors: [
        MockInterceptor(
          [
            Response(code: 200, body: ResponseBody.string('OK')),
          ],
        ),
      ],
    );

    final request = Request.get('http://mock.test.io');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);
    expect(await response.body.string(), 'OK');
    await response.close();

    await client.close();
  });

  // https://github.com/flutterchina/dio/issues/793
  group('Following Redirects, Auth And Cookies', () {
    final invalid =
        {'username': 'tomsmith', 'password': 'badpassword'}.asForm();
    final valid =
        {'username': 'tomsmith', 'password': 'SuperSecretPassword!'}.asForm();

    test('Invalid', () async {
      final client = Restio(cookieJar: MyCookieJar());
      final request = post(
        'https://the-internet.herokuapp.com/authenticate',
        body: invalid,
      );
      final response = await requestResponse(client, request);
      final data = await response.body.string();
      await response.close();

      expect(response.code, 200);
      expect(response.redirects.length, 1);
      expect(data, contains('Your password is invalid!'));
      expect(data, contains('Login Page'));

      await client.close();
    });

    test('Valid', () async {
      final client = Restio(cookieJar: MyCookieJar());
      final request = post(
        'https://the-internet.herokuapp.com/authenticate',
        body: valid,
      );
      final response = await requestResponse(client, request);
      final data = await response.body.string();
      await response.close();

      expect(response.code, 200);
      expect(response.redirects.length, 1);
      expect(data, contains('Secure Area'));

      await client.close();
    });
  });
}

class _RetryAfterInterceptor implements Interceptor {
  final int seconds;

  _RetryAfterInterceptor(this.seconds);

  @override
  Future<Response> intercept(Chain chain) async {
    final request = chain.request;

    final response = await chain.proceed(request);

    return response.copyWith(
      headers:
          (response.headers.toBuilder()..set('Retry-After', seconds)).build(),
    );
  }
}

class MyCookieJar implements CookieJar {
  final jar = <String, List<Cookie>>{};

  @override
  Future<List<Cookie>> load(Request request) async {
    return jar[request.uri.host] ?? const [];
  }

  @override
  Future<void> save(Response response) async {
    final host = response.request.uri.host;
    jar[host] = response.cookies;
  }
}
