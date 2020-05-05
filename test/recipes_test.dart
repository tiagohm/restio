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
    const client = Restio();
    final request = get('https://postman-echo.com/get');
    final call = client.newCall(request);
    final response = await call.execute();
    expect(response.code, 200);
    await response.close();
  });

  test('Performing a POST request', () async {
    const client = Restio();
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
  });

  test('Simple Get', () async {
    const client = Restio();
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
  });

  test('Cancelling a Call', () async {
    const client = Restio();
    final request = get('https://httpbin.org/delay/10');

    final call = client.newCall(request);
    Timer(const Duration(seconds: 5), () => call.cancel('Cancelado!'));

    expect(() async {
      final response = await call.execute();
      await response.close();
    }, throwsA(isA<CancelledException>()));
  });

  test('Posting a String', () async {
    const client = Restio();
    final request = post(
      'https://postman-echo.com/post',
      body: 'Olá!'.asBody(),
      headers: {'content-type': 'application/json'}.asHeaders(),
    );

    final data = await requestJson(client, request);

    expect(data['data'], 'Olá!');
    expect(data['headers']['content-length'], '5');
    expect(data['headers']['content-type'], 'application/json');
  });

  test('Posting Form Parameters', () async {
    const client = Restio();
    final request = post(
      'https://postman-echo.com/post',
      body: {'a': 'b', 'c': 'd'}.asForm(),
    );

    final data = await requestJson(client, request);

    expect(data['form']['a'], 'b');
    expect(data['form']['c'], 'd');
  });

  test('Posting a Multipart Request', () async {
    const client = Restio();
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
    expect(data['data']['type'], 'Buffer');
    expect(data['data']['data'], const [
      57, 142, 52, 40, 70, //
      185, 190, 43, 80, 153, //
    ]);
  });

  test('Posting Binary File By HTTP2', () async {
    var isDone = false;

    void onProgress(Request entity, int sent, int total, bool done) {
      print('sent: $sent, total: $total, done: $done');
      isDone = done;
    }

    final client = Restio(onUploadProgress: onProgress, http2: true);

    final request = post(
      'https://httpbin.org/post',
      body: File('./test/assets/binary.dat').asBody(),
    );

    final data = await requestJson(client, request);

    expect(isDone, true);
    expect(
        data['data'], 'data:application/octet-stream;base64,OY40KEa5vitQmQ==');
  });

  test('User-Agent', () async {
    const client = Restio(options: RequestOptions(userAgent: 'Restio (Dart)'));

    var request = get('https://postman-echo.com/get');
    var data = await requestJson(client, request);

    expect(data['headers']['user-agent'], 'Restio (Dart)');

    request = get(
      'https://postman-echo.com/get',
      headers: {HttpHeaders.userAgentHeader: 'jrit549ytyh549'}.asHeaders(),
    );

    data = await requestJson(client, request);

    expect(data['headers']['user-agent'], 'jrit549ytyh549');
  });

  test('Posting a File', () async {
    const client = Restio();
    final request = post(
      'https://api.github.com/markdown/raw',
      body: '# Restio'.asBody(MediaType(type: 'text', subType: 'x-markdown')),
    );

    final data = await requestString(client, request);
    expect(data,
        '<h1>\n<a id="user-content-restio" class="anchor" href="#restio" aria-hidden="true"><span aria-hidden="true" class="octicon octicon-link"></span></a>Restio</h1>\n');
  });

  test('Content-Type Auto Detect', () async {
    const client = Restio();
    final request = post(
      'https://httpbin.org/post',
      body: File('./test/assets/css.css').asBody(),
    );

    final data = await requestJson(client, request);
    expect(data['headers']['Content-Type'], 'text/css');
  });

  test('Basic Auth', () async {
    const client = Restio(
      options: RequestOptions(
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
  });

  test('Bearer Auth', () async {
    const client = Restio();
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
  });

  test('Digest Auth', () async {
    const client = Restio(
      options: RequestOptions(
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
  });

  test('Hawk Auth', () async {
    const client = Restio(
      options: RequestOptions(
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
  });

  test('Queries Should Be Included In the Hawk Auth Resource', () async {
    const client = Restio(
      options: RequestOptions(
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
  });

  test('Timeout', () async {
    const client = Restio(
      options: RequestOptions(
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
  });

  test('Queries', () async {
    const client = Restio();
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
  });

  test('Raw Data', () async {
    const client = Restio();
    final request = get('https://httpbin.org/robots.txt');

    final call = client.newCall(request);
    final response = await call.execute();
    final data = await response.body.raw();
    await response.close();

    expect(data.length, 30);
  });

  test('Gzip', () async {
    const client = Restio();
    final request = get('https://httpbin.org/gzip');
    final data = await requestJson(client, request);
    expect(data['gzipped'], true);
  });

  test('Deflate', () async {
    const client = Restio();
    final request = get('https://httpbin.org/deflate');
    final data = await requestJson(client, request);
    expect(data['deflated'], true);
  });

  test('Brotli', () async {
    const client = Restio();
    final request = get('https://httpbin.org/brotli');
    final data = await requestJson(client, request);
    expect(data['brotli'], true);
  });

  group('Redirects', () {
    const client = Restio(options: RequestOptions(maxRedirects: 9));

    test('Absolute redirects n times', () async {
      final request = get('https://httpbin.org/absolute-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);

      await response.close();
    });

    test('Relative redirects n times', () async {
      final request = get('https://httpbin.org/relative-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);
      expect(response.redirects[6].request.uri.path, '/get');

      await response.close();
    });

    test('Too many redirects exception', () async {
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
    });
  });

  group('Redirects with DNS', () {
    final client = Restio(
      options: RequestOptions(
        maxRedirects: 9,
        dns: DnsOverUdp.google(),
      ),
    );

    test('Absolute redirects n times', () async {
      final request = get('https://httpbin.org/absolute-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);

      await response.close();
    });

    test('Relative redirects n times', () async {
      final request = get('https://httpbin.org/relative-redirect/7');
      final call = client.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);
      expect(response.redirects[6].request.uri.path, '/get');

      await response.close();
    });

    test('Too many redirects exception', () async {
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
    });
  });

  test('Chunked', () async {
    const client = Restio();
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
  });

  test('Pause & Resume', () async {
    const client = Restio();
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
  });

  test('Retry after', () async {
    const client = Restio();
    final retryAfterClient = client.copyWith(networkInterceptors: [
      _RetryAfterInterceptor(15),
    ]);

    final request = get('https://httpbin.org/absolute-redirect/1');
    final call = retryAfterClient.newCall(request);
    final response = await call.execute();
    await response.close();
    expect(response.totalMilliseconds, greaterThan(15000));
  });

  test('HTTP2', () async {
    const client = Restio(http2: true);

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
  });

  test('Client Certificate', () async {
    const client = Restio(clientCertificateJar: MyClientCertificateJar());
    final request = get('https://localhost:3002');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final json = await response.body.string();
    await response.close();

    expect(json, 'Olá Tiago!');
  });

  test('Proxy', () async {
    const client = Restio(
      options: RequestOptions(
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
  });

  test('Auth Proxy', () async {
    const client = Restio(
      options: RequestOptions(
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
    expect(response.dnsIp, isNotNull);
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
    expect(response.dnsIp, isNotNull);
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
  });

  test('Force Accept-Encoding', () async {
    const client = Restio(http2: true);

    final request = get(
      'https://http2.pro/api/v1',
      headers: {HttpHeaders.acceptEncodingHeader: 'gzip'}.asHeaders(),
    );
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);
    expect(response.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
  });

  test('Fix DNS timeout bug', () async {
    final dns = DnsOverUdp.ip('1.1.1.1');
    final client = Restio(options: RequestOptions(dns: dns));

    final request = get('https://httpbin.org/absolute-redirect/5');
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);
  });

  test('Cookies', () async {
    const client = Restio();
    final request = get('https://postman-echo.com/get');
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);
    expect(response.cookies.length, 1);
    expect(response.cookies[0].name, 'sails.sid');
  });

  test('Version', () async {
    const client = Restio();
    final request = get('https://httpbin.org/get');
    final call = client.newCall(request);
    final response = await call.execute();
    final json = await response.body.json();
    await response.close();

    print(json);

    final pubSpec = await PubSpec.load(Directory('.'));

    expect(response.code, 200);
    expect(json['headers']['User-Agent'], 'Restio/${pubSpec.version}');
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

    call = client.newCall(request);
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

    call = client.newCall(request);
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

    call = client.newCall(request);
    response = await call.execute();
    text = await response.body.string();
    expect(text, 'Restio Caching test!');
    await response.close();

    expect(response.code, 200);
    expect(response.spentMilliseconds, isNonZero);
    expect(response.totalMilliseconds, isNonZero);
    expect(response.networkResponse, isNotNull);
    expect(response.cacheResponse, isNull);
  });

  test('Empty Cache-Control Value', () async {
    const client = Restio();
    final request = get(
      'https://httpbin.org/get',
      headers: {'cache-control': ''}.asHeaders(),
    );
    final call = client.newCall(request);
    final response = await call.execute();
    await response.close();

    expect(response.code, 200);
  });

  test('Encoded Form Body', () async {
    const client = Restio();
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
  });

  test('Fix Default JSON Encoding', () async {
    const client = Restio();
    final request = get('http://www.mocky.io/v2/5e2d86473000005000e77d19');
    final call = client.newCall(request);
    final response = await call.execute();
    final json = await response.body.json();
    await response.close();

    expect(response.code, 200);

    expect(json, 'este é um corpo UTF-8');
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
  });

  test('Redirect Policy', () async {
    var client = const Restio(
      redirectPolicies: [
        DomainCheckRedirectPolicy(['goo.gle', 'www.blog.google']),
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
  });

  group('Request Options', () {
    const client = Restio(
      options: RequestOptions(
        auth: BasicAuthenticator(username: 'c', password: 'd'),
        followRedirects: true,
        maxRedirects: 200,
        userAgent: 'pqrstuvwxyz',
      ),
    );
    test('Authentication', () async {
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
    });

    test('Follow Redirects', () async {
      const options = RequestOptions(followRedirects: false);
      final request = get('https://httpbin.org/redirect/1', options: options);
      final response = await requestResponse(client, request);
      await response.close();

      expect(response.code, 302);
    });

    test('Too many redirects exception', () async {
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
    });

    test('User-Agent', () async {
      const options = RequestOptions(userAgent: 'abcdefghijklmno');
      final request = get('https://postman-echo.com/get', options: options);
      final data = await requestJson(client, request);

      expect(data['headers']['user-agent'], 'abcdefghijklmno');
    });

    test('DNS', () async {
      final options = RequestOptions(dns: DnsOverHttps.google());
      final request = get('https://postman-echo.com/get', options: options);
      final response = await requestResponse(client, request);

      expect(response.dnsIp, isNotNull);
    });

    test('Authentication via HTTP2', () async {
      const options = RequestOptions(
        auth: BasicAuthenticator(username: 'a', password: 'b'),
      );

      final request =
          get('https://httpbin.org/basic-auth/a/b', options: options);
      final response =
          await requestResponse(client.copyWith(http2: true), request);

      expect(response.code, 200);

      final data = await response.body.json();
      await response.close();

      expect(data['authenticated'], true);
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
      headers: (response.headers.toBuilder()
            ..set(HttpHeaders.retryAfterHeader, seconds))
          .build(),
    );
  }
}

class MyClientCertificateJar implements ClientCertificateJar {
  const MyClientCertificateJar();

  @override
  Future<ClientCertificate> get(String host, int port) async {
    if (host == 'localhost' && port == 3002) {
      return ClientCertificate(
        await File('./test/node/ca/certs/tiago.crt').readAsBytes(),
        await File('./test/node/ca/certs/tiago.key').readAsBytes(),
        password: '123mudar',
      );
    } else {
      return null;
    }
  }
}
