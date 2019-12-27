import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/src/client_certificate.dart';
import 'package:restio/src/client_certificate_jar.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  final client = Restio(
    interceptors: [
      LogInterceptor(),
    ],
  );

  test('Performing a GET request', () async {
    final request = Request.get('https://postman-echo.com/get');
    final call = client.newCall(request);
    final response = await call.execute();
    expect(response.code, 200);
  });

  test('Performing a POST request', () async {
    final request = Request.post(
      'https://postman-echo.com/post',
      body: RequestBody.string(
        'This is expected to be sent back as part of response body.',
        contentType: MediaType.text,
      ),
    );
    final call = client.newCall(request);
    final response = await call.execute();
    expect(response.code, 200);
    final dynamic json = await response.body.json();
    expect(json['headers']['content-length'], '58');
    expect(json['json'], null);
  });

  test('Simple Get', () async {
    final request = Request.get('https://httpbin.org/json');
    final call = client.newCall(request);
    final response = await call.execute();

    expect(response.body.contentType.type, 'application');
    expect(response.body.contentType.subType, 'json');
    expect(response.body.contentLength, 221);
    expect(response.code, 200);
    expect(response.isSuccess, true);
    expect(response.message, 'OK');
  });

  test('Cancelling a Call', () async {
    final request = Request.get('https://httpbin.org/delay/10');

    final call = client.newCall(request);
    Future.delayed(const Duration(seconds: 5), () => call.cancel('Cancelado!'));

    try {
      await call.execute();
    } on CancelledException catch (e) {
      expect(e.message, 'Cancelado!');
    }
  });

  test('Posting a String', () async {
    final request = Request.post(
      'https://postman-echo.com/post',
      body: RequestBody.string('Olá!', contentType: MediaType.text),
      headers: HeadersBuilder().add('content-type', 'application/json').build(),
    );

    final dynamic data = await requestJson(client, request);

    expect(data['data'], 'Olá!');
    expect(data['headers']['content-length'], '5');
    expect(data['headers']['content-type'], 'application/json');
  });

  test('Posting Form Parameters', () async {
    final request = Request.post(
      'https://postman-echo.com/post',
      body: FormBody.fromMap(<String, dynamic>{
        'a': 'b',
        'c': 'd',
      }),
    );

    final dynamic data = await requestJson(client, request);

    expect(data['form']['a'], 'b');
    expect(data['form']['c'], 'd');
  });

  test('Posting a Multipart Request', () async {
    final request = Request.post(
      'https://postman-echo.com/post',
      body: MultipartBody(
        parts: [
          Part.form('a', 'b'),
          Part.form('c', 'd'),
          Part.file(
            'e',
            'text.txt',
            RequestBody.file(
              File('./test/assets/text.txt'),
            ),
          ),
        ],
      ),
    );

    final dynamic data = await requestJson(client, request);

    expect(data['form']['a'], 'b');
    expect(data['form']['c'], 'd');
    expect(data['files']['text.txt'],
        'data:application/octet-stream;base64,YQpiCmMK');
  });

  test('Posting Binary File', () async {
    var isDone = false;

    void onProgress(request, sent, total, done) {
      print('sent: $sent, total: $total, done: $done');
      isDone = done;
    }

    final progressClient = client.copyWith(
      onUploadProgress: onProgress,
    );

    final request = Request.post(
      'https://postman-echo.com/post',
      body: MultipartBody(
        parts: [
          Part.file(
            'binary',
            'binary.dat',
            RequestBody.file(
              File('./test/assets/binary.dat'),
            ),
          ),
        ],
      ),
    );

    final dynamic data = await requestJson(progressClient, request);

    expect(isDone, true);
    expect(data['files']['binary.dat'],
        'data:application/octet-stream;base64,OY40KEa5vitQmQ==');
  });

  test('User-Agent', () async {
    final userAgentClient = client.copyWith(userAgent: 'Restio/0.1.0 (Dart)');

    var request = Request.get('https://postman-echo.com/get');
    dynamic data = await requestJson(userAgentClient, request);

    expect(data['headers']['user-agent'], 'Restio/0.1.0 (Dart)');

    request = Request.get(
      'https://postman-echo.com/get',
      headers: Headers.of(
          <String, dynamic>{HttpHeaders.userAgentHeader: 'jrit549ytyh549'}),
    );

    data = await requestJson(client, request);

    expect(data['headers']['user-agent'], 'jrit549ytyh549');
  });

  test('Posting a File', () async {
    final request = Request.post(
      'https://api.github.com/markdown/raw',
      body: RequestBody.string(
        '# Restio',
        contentType: MediaType(
          type: 'text',
          subType: 'x-markdown',
        ),
      ),
    );

    final dynamic data = await requestString(client, request);
    expect(data,
        '<h1>\n<a id="user-content-restio" class="anchor" href="#restio" aria-hidden="true"><span aria-hidden="true" class="octicon octicon-link"></span></a>Restio</h1>\n');
  });

  test('Basic Auth 1', () async {
    final authClient = client.copyWith(
      auth: const BasicAuthenticator(
        username: 'postman',
        password: 'password',
      ),
    );

    final request = Request.get('https://postman-echo.com/basic-auth');
    final response = await requestResponse(authClient, request);

    expect(response.code, 200);

    final dynamic data = await response.body.json();
    expect(data['authenticated'], true);
  });

  test('Basic Auth 2', () async {
    final authClient = client.copyWith(
      auth: const BasicAuthenticator(
        username: 'a',
        password: 'b',
      ),
    );

    final request = Request.get('https://httpbin.org/basic-auth/a/b');
    final response = await requestResponse(authClient, request);

    expect(response.code, 200);

    final dynamic data = await response.body.json();
    expect(data['authenticated'], true);
  });

  test('Bearer Auth', () async {
    final authClient = client.copyWith(
      auth: const BearerAuthenticator(
        token: '123',
      ),
    );

    final request = Request.get('https://httpbin.org/bearer');

    final response = await requestResponse(authClient, request);
    expect(response.code, 200);

    final dynamic data = await response.body.json();
    expect(data['authenticated'], true);
    expect(data['token'], '123');
  });

  test('Digest Auth', () async {
    final authClient = client.copyWith(
      auth: const DigestAuthenticator(
        username: 'postman',
        password: 'password',
      ),
    );

    final request = Request.get('https://postman-echo.com/digest-auth');

    final response = await requestResponse(authClient, request);
    expect(response.code, 200);

    final dynamic data = await response.body.json();
    expect(data['authenticated'], true);
  });

  test('Hawk Auth', () async {
    final authClient = client.copyWith(
      auth: const HawkAuthenticator(
        id: 'dh37fgj492je',
        key: 'werxhqb98rpaxn39848xrunpaw3489ruxnpa98w4rxn',
      ),
    );

    final request = Request.get('https://postman-echo.com/auth/hawk');

    final response = await requestResponse(authClient, request);
    expect(response.code, 200);

    final dynamic data = await response.body.json();
    expect(data['message'], 'Hawk Authentication Successful');
  });

  test('Timeout', () async {
    final timeoutClient = client.copyWith(
      connectTimeout: const Duration(seconds: 2),
      writeTimeout: const Duration(seconds: 2),
      receiveTimeout: const Duration(seconds: 2),
    );

    final request = Request.get('https://httpbin.org/delay/10');

    final call = timeoutClient.newCall(request);

    try {
      await call.execute();
    } on TimedOutException catch (e) {
      expect(e.message, '');
    }
  });

  test('Queries', () async {
    final request = Request.get(
      'https://api.github.com/search/repositories?q=flutter&sort=stars',
      queries: Queries.of(<String, dynamic>{
        'order': 'desc',
        'per_page': '2',
      }),
    );

    expect(request.queries.first('q'), 'flutter');
    expect(request.queries.first('sort'), 'stars');
    expect(request.queries.first('order'), 'desc');
    expect(request.queries.first('per_page'), '2');

    final response = await requestResponse(client, request);
    expect(response.code, 200);

    final dynamic data = await response.body.json();
    expect(data['items'].length, 2);
    expect(data['items'][0]['full_name'], 'flutter/flutter');
  });

  test('Raw Data', () async {
    final request = Request.get('https://httpbin.org/robots.txt');

    final call = client.newCall(request);
    final response = await call.execute();
    final dynamic data = await response.body.compressed();

    expect(data.length, 50);
  });

  test('Gzip', () async {
    final request = Request.get('https://httpbin.org/gzip');

    final dynamic data = await requestJson(client, request);

    expect(data['gzipped'], true);
  });

  test('Deflate', () async {
    final request = Request.get('https://httpbin.org/deflate');

    final dynamic data = await requestJson(client, request);

    expect(data['deflated'], true);
  });

  test('Brotli', () async {
    final request = Request.get('https://httpbin.org/brotli');

    final dynamic data = await requestJson(client, request);

    expect(data['brotli'], true);
  });

  group('Redirects', () {
    final redirectClient = client.copyWith(maxRedirects: 9);

    test('Absolute redirects n times', () async {
      final request = Request.get('https://httpbin.org/absolute-redirect/7');
      final call = redirectClient.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);
    });

    test('Relative redirects n times', () async {
      final request = Request.get('https://httpbin.org/relative-redirect/7');
      final call = redirectClient.newCall(request);
      final response = await call.execute();

      expect(response.code, 200);
      expect(response.redirects.length, 7);
      expect(response.redirects[6].request.uri.path, '/get');
    });

    test('Too many redirects exception', () async {
      final request = Request.get('https://httpbin.org/absolute-redirect/10');
      final call = redirectClient.newCall(request);

      try {
        await call.execute();
      } on TooManyRedirectsException catch (e) {
        expect(e.message, 'Too many redirects: 10');
        expect(e.uri, Uri.parse('https://httpbin.org/absolute-redirect/10'));
      }
    });
  });

  test('Chunked', () async {
    var isDone = false;

    void onProgress(response, sent, total, done) {
      print('sent: $sent, total: $total, done: $done');
      isDone = done;
    }

    final progressClient = client.copyWith(
      onDownloadProgress: onProgress,
    );

    final request = Request.get('https://httpbin.org/stream-bytes/36001');

    final call = progressClient.newCall(request);
    final response = await call.execute();
    final dynamic data = await response.body.compressed();

    expect(data.length, 36001);
    expect(isDone, true);
  });

  test('Base Uri', () async {
    final clientWithBaseUri = client.copyWith(
      baseUri: Uri.parse('https://api.github.com?sort=stars'),
    );

    var request = Request.get(
      '/search/repositories?q=flutter',
      queries: Queries.of(<String, dynamic>{
        'order': 'desc',
        'per_page': '2',
      }),
    );

    var response = await requestResponse(clientWithBaseUri, request);

    expect(response.connectRequest.uri.toString(),
        'https://api.github.com/search/repositories');
    expect(response.connectRequest.queries.first('q'), 'flutter');
    expect(response.connectRequest.queries.first('sort'), 'stars');
    expect(response.connectRequest.queries.first('order'), 'desc');
    expect(response.connectRequest.queries.first('per_page'), '2');

    request = Request.get('https://api.github.com/repos/tiagohm/restio');

    response = await requestResponse(clientWithBaseUri, request);

    expect(response.connectRequest.uri.toString(),
        'https://api.github.com/repos/tiagohm/restio');
  });

  test('Pause & Resume', () async {
    //  TODO:
  });

  test('Retry after', () async {
    final retryAfterClient = client.copyWith(networkInterceptors: [
      _RetryAfterInterceptor(15),
    ]);

    final request = Request.get('https://httpbin.org/absolute-redirect/1');
    final call = retryAfterClient.newCall(request);
    final response = await call.execute();
    expect(response.elapsedMilliseconds > 15000, true);
  });

  test('HTTP2', () async {
    final http2Client = client.copyWith(isHttp2: true);

    final request = Request.get('https://http2.pro/api/v1');
    final call = http2Client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final dynamic json = await response.body.json();

    expect(json['http2'], 1);
    expect(json['protocol'], 'HTTP/2.0');
    expect(json['push'], 0);
    expect(response.headers.first(HttpHeaders.contentEncodingHeader), 'br');
  });

  test('Client Certificate', () async {
    final certificateClient = client.copyWith(
      clientCertificateJar: MyClientCertificateJar(),
    );

    final request = Request.get('https://localhost:9000');
    final call = certificateClient.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final dynamic json = await response.body.json();

    expect(json, 'HI!');
  });

  test('Proxy', () async {
    final proxyClient = client.copyWith(
      proxy: const Proxy(
        host: 'localhost',
        port: 3001,
      ),
      auth: const BasicAuthenticator(
        username: 'c',
        password: 'd',
      ),
    );

    final request = Request.get('http://httpbin.org/basic-auth/c/d');
    final call = proxyClient.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final dynamic json = await response.body.json();

    expect(json['authenticated'], true);
    expect(response.headers.first('x-http-proxy'), 'true');
  });

  test('Auth Proxy', () async {
    final proxyClient = client.copyWith(
      proxy: const Proxy(
        host: 'localhost',
        port: 3002,
        auth: BasicAuthenticator(
          username: 'a',
          password: 'b',
        ),
      ),
      auth: const BasicAuthenticator(
        username: 'c',
        password: 'd',
      ),
    );

    final request = Request.get('http://httpbin.org/basic-auth/c/d');
    final call = proxyClient.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final dynamic json = await response.body.json();

    expect(json['authenticated'], true);
    expect(response.headers.first('x-http-proxy'), 'true');
  });

  test('DNS-Over-UDP', () async {
    final dns = DnsOverUdp.google();

    final dnsClient = client.copyWith(
      dns: dns,
      auth: BasicAuthenticator(
        username: 'postman',
        password: 'password',
      ),
    );

    final request = Request.get('https://postman-echo.com/basic-auth');
    final call = dnsClient.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final dynamic json = await response.body.json();

    expect(json['authenticated'], true);
    expect(response.dnsIp, isNotNull);
  });

  test('DNS-Over-HTTPS', () async {
    final dns = DnsOverHttps.google();

    final dnsClient = client.copyWith(
      dns: dns,
      auth: BasicAuthenticator(
        username: 'postman',
        password: 'password',
      ),
    );

    final request = Request.get('https://postman-echo.com/basic-auth');
    final call = dnsClient.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);

    final dynamic json = await response.body.json();

    expect(json['authenticated'], true);
    expect(response.dnsIp, isNotNull);
  });

  test('Force Accept-Encoding', () async {
    final http2Client = client.copyWith(isHttp2: true);

    final request = Request.get(
      'https://http2.pro/api/v1',
      headers: Headers.of({
        HttpHeaders.acceptEncodingHeader: 'gzip',
      }),
    );
    final call = http2Client.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);
    expect(response.headers.first(HttpHeaders.contentEncodingHeader), 'gzip');
  });

  test('Fix DNS timeout bug', () async {
    final dns = DnsOverUdp.ip('1.1.1.1');

    final dnsClient = client.copyWith(dns: dns);

    final request = Request.get('https://httpbin.org/absolute-redirect/5');
    final call = dnsClient.newCall(request);
    final response = await call.execute();

    expect(response.code, 200);
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
      headers: response.headers
          .toBuilder()
          .set(HttpHeaders.retryAfterHeader, seconds)
          .build(),
    );
  }
}

class MyClientCertificateJar extends ClientCertificateJar {
  @override
  Future<ClientCertificate> get(String host, int port) async {
    if (host == 'localhost' && port == 9000) {
      return ClientCertificate(
        await File('./test/server/server.crt').readAsBytes(),
        await File('./test/server/server.key').readAsBytes(),
        password: 'qZDTpGTCK4aRQV7JFh7WVnpCu6san4FC',
      );
    } else {
      return null;
    }
  }
}
