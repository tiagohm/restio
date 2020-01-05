@Timeout(Duration(hours: 1))

import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/src/cache/cache_control.dart';
import 'package:test/test.dart';

void main() {
  final client = Restio(
    interceptors: [
      LogInterceptor(),
    ],
  );

  test('Response Caching', () async {
    final cache = Cache(store: MemoryCacheStore());
    final cacheClient = client.copyWith(
      cache: cache,
      networkInterceptors: [
        MockResponseInterceptor(
          headers: {
            'last-modified': obtainDate(const Duration(hours: -1)),
            'expires': obtainDate(const Duration(hours: 1)),
          },
        ),
      ],
    );

    final request = Request.get('http://localhost:8000');
    var call = cacheClient.newCall(request);
    var response = await call.execute();

    expect(await response.body.data.string(), 'ABCDE');
    expect(cache.requestCount, 1);
    expect(cache.networkCount, 1);
    expect(cache.hitCount, 0);

    call = cacheClient.newCall(request);
    response = await call.execute();
    expect(await response.body.data.string(), 'ABCDE');

    expect(cache.requestCount, 2);
    expect(cache.networkCount, 1);
    expect(cache.hitCount, 1);
    expect(response.cacheResponse, isNotNull);
  });
}

String obtainDate(Duration duration) {
  return HttpDate.format(DateTime.now().toUtc().add(duration));
}

class MockResponseInterceptor implements Interceptor {
  final CacheControl cacheControl;
  final Map<String, dynamic> headers;
  final int code;
  final String body;

  MockResponseInterceptor({
    this.cacheControl,
    this.headers,
    this.code,
    String body,
  }) : body = body ?? 'ABCDE';

  @override
  Future<Response> intercept(Chain chain) async {
    final now = DateTime.now();

    return Response(
      request: chain.request,
      headers: Headers.of(headers ?? const {}),
      cacheControl: cacheControl,
      code: code ?? 200,
      receivedAt: now,
      redirects: const [],
      cookies: const [],
      body: ResponseBody.string(
        body,
        contentLength: body.length,
        contentType: MediaType.text,
      ),
    );
  }
}
