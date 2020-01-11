@Timeout(Duration(hours: 1))

import 'dart:convert';
import 'dart:io' as io;

import 'package:restio/restio.dart';
import 'package:restio/src/cache/cache.dart';
import 'package:test/test.dart';

// https://github.com/square/okhttp/blob/master/okhttp/src/test/java/okhttp3/CacheTest.java

const url = 'http://localhost:8000';

final client = Restio(
  interceptors: [
    LogInterceptor(),
  ],
);

void main() {
  void testCacheStore(CacheStore Function() store) {
    Future<void> temporaryRedirectCachedWithCachingHeader(
      int responseCode,
      String headerName,
      String headerValue,
    ) async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                code: responseCode,
                headers: {
                  headerName: headerValue,
                  'location': '/a',
                },
              ),
              MockResponse(
                body: 'a',
                headers: {
                  headerName: headerValue,
                },
              ),
              MockResponse(body: 'b'),
              MockResponse(body: 'c'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'a');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'a');
      await response.body.close();
    }

    Future<void> temporaryRedirectNotCachedWithoutCachingHeader(
      int responseCode,
    ) async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                code: responseCode,
                headers: {
                  'location': '/a',
                },
              ),
              MockResponse(body: 'a'),
              MockResponse(body: 'b'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'a');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'b');
      await response.body.close();
    }

    Future<void> assertNotCached(MockResponse response) async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              response.copyMockWith(body: 'A'),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response1 = await call.execute();

      expect(await response1.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response1 = await call.execute();

      expect(await response1.body.data.string(), 'B');
      await response.body.close();
    }

    Future<void> assertFullyCached(MockResponse response) async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              response.copyMockWith(body: 'A'),
              response.copyMockWith(body: 'B'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response1 = await call.execute();

      expect(await response1.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response1 = await call.execute();

      expect(await response1.body.data.string(), 'A');
      await response.body.close();
    }

    Future<void> testRequestMethod(
      String method,
      bool expectCached,
    ) async {
      // 1. Seed the cache (potentially).
      // 2. Expect a cache hit or miss.

      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(headers: {
                'expires': obtainDate(const Duration(hours: 1)),
                'x-response-id': '1',
              }),
              MockResponse(headers: {
                'x-response-id': '2',
              }),
            ],
          ),
        ],
      );

      final request = Request(
        uri: Uri.parse(url),
        method: method,
        body: requestBodyOrNull(method),
      );

      var call = cacheClient.newCall(request);
      var response = await call.execute();
      await response.body.data.string();
      await response.body.close();

      expect(response.headers.first('x-response-id'), '1');

      call = cacheClient.newCall(request);
      response = await call.execute();
      await response.body.data.string();
      await response.body.close();

      if (expectCached) {
        expect(response.headers.first('x-response-id'), '1');
      } else {
        expect(response.headers.first('x-response-id'), '2');
      }
    }

    Future<void> testMethodInvalidates(
      String method,
    ) async {
      // 1. Seed the cache.
      // 2. Invalidate it.
      // 3. Expect a cache miss.
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
              MockResponse(body: 'B'),
              MockResponse(body: 'C'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request(
        uri: Uri.parse(url),
        method: method,
        body: requestBodyOrNull(method),
      );
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'C');
      await response.body.close();
    }

    Future<void> assertNonIdentityEncodingCached(MockResponse response) async {
// 1. Seed the cache.
      // 2. Invalidate it.
      // 3. Expect a cache miss.
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              response.copyMockWith(
                body: gzip('ABCABCABC'),
                headers: {
                  ...response.headers.toMap(),
                  'content-encoding': 'gzip',
                },
              ),
              MockResponse(code: io.HttpStatus.notModified),
              MockResponse(code: io.HttpStatus.notModified),
            ],
          ),
        ],
      );

      // At least three request/response pairs are required because after the first request is cached
      // a different execution path might be taken. Thus modifications to the cache applied during
      // the second request might not be visible until another request is performed.

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response1 = await call.execute();

      expect(await response1.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response1 = await call.execute();

      expect(await response1.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response1 = await call.execute();

      expect(await response1.body.data.string(), 'ABCABCABC');
      await response.body.close();
    }

    test('Response Caching', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'ABCDE',
                headers: {
                  'last-modified': obtainDate(const Duration(hours: -1)),
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABCDE');
      await response.body.close();

      expect(cache.requestCount, 1);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);

      call = cacheClient.newCall(request);
      response = await call.execute();
      expect(await response.body.data.string(), 'ABCDE');
      await response.body.close();

      expect(cache.requestCount, 2);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 1);
      expect(response is Cacheable, true);
    });

    test('Caching and Redirects', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                code: io.HttpStatus.movedPermanently,
                headers: {
                  'last-modified': obtainDate(const Duration(hours: -1)),
                  'expires': obtainDate(const Duration(hours: 1)),
                  'location': '/foo',
                },
              ),
              MockResponse(
                body: 'ABC',
                headers: {
                  'last-modified': obtainDate(const Duration(hours: -1)),
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
              MockResponse(
                body: 'DEF',
              ),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute(); // Cached.
      expect(await response.body.data.string(), 'ABC');
      await response.body.close();
      expect(response is Cacheable, true);

      // 2 requests + 2 redirect.
      expect(cache.requestCount, 4);
      expect(cache.networkCount, 2);
      expect(cache.hitCount, 2);
    });

    test('Redirect to Cached Response', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              // A primeira requisição "/foo" cria o cache.
              MockResponse(
                body: 'ABC',
                cacheControl: const CacheControl(maxAge: Duration(seconds: 60)),
                headers: {
                  'last-modified': obtainDate(const Duration(hours: -1)),
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
              // A segunda requisição "/bar" redireciona para "/foo" e usa seu cache.
              MockResponse(
                code: io.HttpStatus.movedPermanently,
                headers: {
                  'location': '/foo',
                },
              ),
              // A terceira requisição "/baz" não usa o cache.
              MockResponse(
                body: 'DEF',
              ),
            ],
          ),
        ],
      );

      var request = Request.get('$url/foo');
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABC');
      await response.body.close();

      expect(cache.requestCount, 1);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);

      request = Request.get('$url/bar');
      call = cacheClient.newCall(request);
      response = await call.execute();
      expect(await response.body.data.string(), 'ABC');
      await response.body.close();

      // 2 requests + 1 redirect.
      expect(cache.requestCount, 3);
      expect(cache.networkCount, 2);
      expect(cache.hitCount, 1);
      expect(response is Cacheable, true);

      request = Request.get('$url/baz');
      call = cacheClient.newCall(request);
      response = await call.execute();
      expect(await response.body.data.string(), 'DEF');
      await response.body.close();

      expect(cache.requestCount, 4);
      expect(cache.networkCount, 3);
      expect(cache.hitCount, 1);
      expect(response is Cacheable, true);
    });

    test('Found Cache with Expires Header', () async {
      await temporaryRedirectCachedWithCachingHeader(
        302,
        'expires',
        obtainDate(const Duration(hours: 1)),
      );
    });

    test('Found Cache with Cache-Control Header', () async {
      await temporaryRedirectCachedWithCachingHeader(
        302,
        'cache-control',
        'max-age=60',
      );
    });

    test('Temporary Redirect Cached With Expires Header', () async {
      await temporaryRedirectCachedWithCachingHeader(
        307,
        'expires',
        obtainDate(const Duration(hours: 1)),
      );
    });

    test('Temporary Redirect Cached With Cache-Control Header', () async {
      await temporaryRedirectCachedWithCachingHeader(
        307,
        'cache-control',
        'max-age=60',
      );
    });

    test('Found Not Cached Without Cache Header', () async {
      await temporaryRedirectNotCachedWithoutCachingHeader(302);
    });

    test('Temporary Redirect Not Cached Without Cache Header', () async {
      await temporaryRedirectNotCachedWithoutCachingHeader(307);
    });

    // https://github.com/square/okhttp/issues/2198.
    test('Cached Redirect', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                code: 301,
                headers: {
                  'cache-control': 'max-age=60',
                  'location': '/bar',
                },
              ),
              MockResponse(body: 'ABC'),
              MockResponse(body: 'ABC'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'ABC');
      await response.body.close();
    });

    test('Default Expiration Date Fully Cached For Less Than 24 Hours',
        () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              //      last modified: 105 seconds ago
              //             served:   5 seconds ago
              //   default lifetime: (105 - 5) / 10 = 10 seconds
              //            expires:  10 seconds from served date = 5 seconds from now
              MockResponse(
                body: 'A',
                headers: {
                  'last-modified': obtainDate(const Duration(seconds: -105)),
                  'date': obtainDate(const Duration(seconds: -5)),
                },
              ),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.has('warning'), false);
    });

    // Default Expiration Date Conditionally Cached.

    test('Default Expiration Date Fully Cached For More Than 24 Hours',
        () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              //      last modified: 105 days ago
              //             served:   5 days ago
              //   default lifetime: (105 - 5) / 10 = 10 days
              //            expires:  10 days from served date = 5 days from now
              MockResponse(
                body: 'A',
                headers: {
                  'last-modified': obtainDate(const Duration(days: -105)),
                  'date': obtainDate(const Duration(days: -5)),
                },
              ),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'),
          '113 HttpURLConnection "Heuristic expiration"');
    });

    test('No Default Expiration For Urls With Query String', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'last-modified': obtainDate(const Duration(seconds: -105)),
                  'date': obtainDate(const Duration(seconds: -5)),
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      final request = Request.get('$url?foo=bar');
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    // expirationDateInThePastWithLastModifiedHeader.

    test('Expiration Date In The Past With No Last Modified Header', () async {
      await assertNotCached(MockResponse(headers: {
        'expires': obtainDate(const Duration(hours: -1)),
      }));
    });

    test('Expiration Date In The Future', () async {
      await assertFullyCached(MockResponse(headers: {
        'expires': obtainDate(const Duration(hours: 1)),
      }));
    });

    test('MaxAge Preferred With MaxAge And Expires', () async {
      await assertFullyCached(MockResponse(headers: {
        'date': obtainDate(const Duration(hours: 0)),
        'expires': obtainDate(const Duration(hours: -1)),
        'cache-control': 'max-age=60',
      }));
    });

    // maxAgeInThePastWithDateAndLastModifiedHeaders.

    test('MaxAge In The Past With Date Header But No LastModified Header',
        () async {
      // Chrome interprets max-age relative to the local clock. Both our cache
      // and Firefox both use the earlier of the local and server's clock.
      await assertNotCached(MockResponse(headers: {
        'date': obtainDate(const Duration(seconds: -120)),
        'cache-control': 'max-age=60',
      }));
    });

    test('MaxAge In The Future With Date Header', () async {
      await assertFullyCached(MockResponse(headers: {
        'date': obtainDate(const Duration(hours: 0)),
        'cache-control': 'max-age=60',
      }));
    });

    test('MaxAge In The Future With No Date Header', () async {
      await assertFullyCached(MockResponse(headers: {
        'cache-control': 'max-age=60',
      }));
    });

    test('MaxAge With Last Modified But No Served Date', () async {
      await assertFullyCached(MockResponse(headers: {
        'date': obtainDate(const Duration(seconds: 0)),
        'last-modified': obtainDate(const Duration(seconds: -120)),
        'cache-control': 'max-age=60',
      }));
    });

    test('MaxAge In The Future With Date And LastModified Headers', () async {
      await assertFullyCached(MockResponse(headers: {
        'last-modified': obtainDate(const Duration(seconds: -120)),
        'cache-control': 'max-age=60',
      }));
    });

    test('MaxAge Preferred Over Lower Shared MaxAge', () async {
      await assertFullyCached(MockResponse(headers: {
        'date': obtainDate(const Duration(minutes: -2)),
        'cache-control': 's-maxage=60, max-age=180',
      }));
    });

    test('MaxAge Preferred Over Higher MaxAge', () async {
      await assertNotCached(MockResponse(headers: {
        'date': obtainDate(const Duration(minutes: -2)),
        'cache-control': 's-maxage=180, max-age=60',
      }));
    });

    test('Options Is Not Cached', () async {
      await testRequestMethod(HttpMethod.options, false);
    });

    test('Get Is Cached', () async {
      await testRequestMethod(HttpMethod.get, true);
    });

    test('Head Is Not Cached', () async {
      // We could support this but choose not to for implementation simplicity.
      await testRequestMethod(HttpMethod.head, false);
    });

    test('Post Is Not Cached', () async {
      // We could support this but choose not to for implementation simplicity.
      await testRequestMethod(HttpMethod.post, false);
    });

    test('Put Is Not Cached', () async {
      await testRequestMethod(HttpMethod.put, false);
    });

    test('Delete Is Not Cached', () async {
      await testRequestMethod(HttpMethod.delete, false);
    });

    test('Trace Is Not Cached', () async {
      await testRequestMethod(HttpMethod.trace, false);
    });

    test('Post Invalidates Cache', () async {
      await testMethodInvalidates(HttpMethod.post);
    });

    test('Put Invalidates Cache', () async {
      await testMethodInvalidates(HttpMethod.put);
    });

    test('Delete Invalidates Cache', () async {
      await testMethodInvalidates(HttpMethod.delete);
    });

    test('Post Invalidates Cache With Uncacheable Response', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          // 1. Seed the cache.
          // 2. Invalidate it with an uncacheable response.
          // 3. Expect a cache miss.
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
              MockResponse(body: 'B', code: 500),
              MockResponse(body: 'C'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.post(url, body: requestBodyOrNull('POST'));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'C');
      await response.body.close();
    });

    test('Put Invalidates With No Content Response', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          // 1. Seed the cache.
          // 2. Invalidate it.
          // 3. Expect a cache miss.
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
              MockResponse(code: 204),
              MockResponse(body: 'C'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.put(url,
          body: RequestBody.string('foo', contentType: MediaType.text));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), '');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'C');
      await response.body.close();
    });

    // etag.
    // etagAndExpirationDateInThePast.

    test('ETag And Expiration Date In The Future', () async {
      await assertFullyCached(MockResponse(
        headers: {
          'etag': 'v1',
          'last-modified': obtainDate(const Duration(hours: -2)),
          'expires': obtainDate(const Duration(hours: 1)),
        },
      ));
    });

    test('Cache-Control With No Cache', () async {
      await assertNotCached(MockResponse(
        headers: {'cache-control': 'no-cache'},
      ));
    });

    // cacheControlNoCacheAndExpirationDateInTheFuture.

    test('Pragma With No Cache', () async {
      await assertNotCached(MockResponse(
        headers: {'pragma': 'no-cache'},
      ));
    });

    // pragmaNoCacheAndExpirationDateInTheFuture.

    test('Cache-Control No Store', () async {
      await assertNotCached(MockResponse(
        headers: {'cache-control': 'no-store'},
      ));
    });

    test('Cache-Control With no-store And Expiration Date In The Future',
        () async {
      await assertNotCached(MockResponse(
        headers: {
          'last-modified': obtainDate(const Duration(hours: -2)),
          'expires': obtainDate(const Duration(hours: 1)),
          'cache-control': 'no-store',
        },
      ));
    });

    test('Partial Range Responses Do Not Corrupt Cache', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          // 1. Request a range.
          // 2. Request a full document, expecting a cache miss.
          MockResponseInterceptor(
            [
              MockResponse(
                code: io.HttpStatus.partialContent,
                body: 'AA',
                headers: {
                  'expires': obtainDate(const Duration(hours: 1)),
                  'content-range': 'bytes 1000-1001/2000',
                },
              ),
              MockResponse(body: 'BB'),
            ],
          ),
        ],
      );

      var request =
          Request.get(url, headers: Headers.of({'range': 'bytes=1000-1001'}));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'AA');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'BB');
      await response.body.close();
    });

    test('Server Returns Document Older Than Cache', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'last-modified': obtainDate(const Duration(hours: -2)),
                  'expires': obtainDate(const Duration(hours: -1)),
                },
              ),
              MockResponse(
                body: 'B',
                headers: {
                  'last-modified': obtainDate(const Duration(hours: -4)),
                },
              ),
              MockResponse(code: io.HttpStatus.notModified),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Client Side No Store', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'cache-control': 'max-age=60',
                },
              ),
              MockResponse(
                body: 'B',
                headers: {
                  'cache-control': 'max-age=60',
                },
              ),
            ],
          ),
        ],
      );

      var request =
          Request.get(url, cacheControl: const CacheControl(noStore: true));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Non Identity Encoding And Conditional Cache', () async {
      await assertNonIdentityEncodingCached(MockResponse(
        headers: {
          'last-modified': obtainDate(const Duration(hours: -2)),
          'expires': obtainDate(const Duration(hours: -1)),
        },
      ));
    });

    test('Non Identity Encoding And Full Cache', () async {
      await assertNonIdentityEncodingCached(MockResponse(
        headers: {
          'last-modified': obtainDate(const Duration(hours: -2)),
          'expires': obtainDate(const Duration(hours: 1)),
        },
      ));
    });

    test(
        'Previously Not Gzipped Content Is Not Modified And Specifies Gzip Encoding',
        () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'ABCABCABC',
                headers: {
                  'content-type': 'text/plain',
                  'last-modified': obtainDate(const Duration(hours: -2)),
                  'expires': obtainDate(const Duration(hours: -1)),
                },
              ),
              MockResponse(
                code: io.HttpStatus.notModified,
                headers: {
                  'content-type': 'text/plain',
                  'content-encoding': 'gzip',
                },
              ),
              MockResponse(body: 'DEFDEFDEF'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'DEFDEFDEF');
      await response.body.close();
    });

    test('Changed Gzipped Content Is Not Modified And Specifies New Encoding',
        () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: gzip('ABCABCABC'),
                headers: {
                  'content-type': MediaType.text.toString(),
                  'content-encoding': 'gzip',
                  'last-modified': obtainDate(const Duration(hours: -2)),
                  'expires': obtainDate(const Duration(hours: -1)),
                },
              ),
              MockResponse(
                code: io.HttpStatus.notModified,
                headers: {
                  'content-type': MediaType.text.toString(),
                  'content-encoding': 'deflate',
                },
              ),
              MockResponse(body: 'DEFDEFDEF'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'DEFDEFDEF');
      await response.body.close();
    });

    test('NotModified Specifies Encoding', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: gzip('ABCABCABC'),
                headers: {
                  'content-type': MediaType.text.toString(),
                  'content-encoding': 'gzip',
                  'last-modified': obtainDate(const Duration(hours: -2)),
                  'expires': obtainDate(const Duration(hours: -1)),
                },
              ),
              MockResponse(
                code: io.HttpStatus.notModified,
                headers: {
                  'content-encoding': 'gzip',
                },
              ),
              MockResponse(body: 'DEFDEFDEF'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'DEFDEFDEF');
      await response.body.close();
    });

    // https://github.com/square/okhttp/issues/947.
    test('Gzip And Vary On Accept Encoding', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: gzip('ABCABCABC'),
                headers: {
                  'vary': 'accept-encoding',
                  'content-encoding': 'gzip',
                  'cache-control': 'max-age=60',
                },
              ),
              MockResponse(body: 'FAIL'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'ABCABCABC');
      await response.body.close();
    });

    // expiresDateBeforeModifiedDate.

    test('Request MaxAge', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'date': obtainDate(const Duration(minutes: -1)),
                  'last-modified': obtainDate(const Duration(hours: -2)),
                  'expires': obtainDate(const Duration(hours: 1)),
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          cacheControl: const CacheControl(maxAge: Duration(seconds: 30)));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Request MinFresh', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'date': obtainDate(const Duration(minutes: 0)),
                  'cache-control': 'max-age=60',
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          cacheControl: const CacheControl(minFresh: Duration(seconds: 120)));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Request MaxStale', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'date': obtainDate(const Duration(minutes: -4)),
                  'cache-control': 'max-age=120',
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          cacheControl: const CacheControl(maxStale: Duration(seconds: 180)));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'),
          '110 HttpURLConnection "Response is stale"');
    });

    test('Request MaxStale Directive With No Value', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'date': obtainDate(const Duration(minutes: -4)),
                  'cache-control': 'max-age=120',
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      // With max-stale, we'll return that stale response.
      request =
          Request.get(url, headers: Headers.of({'cache-control': 'max-stale'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'),
          '110 HttpURLConnection "Response is stale"');
    });

    test('Request MaxStale Not Honored With Must Revalidate', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'date': obtainDate(const Duration(minutes: -4)),
                  'cache-control': 'max-age=120, must-revalidate',
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      // With max-stale, we'll return that stale response.
      request = Request.get(url,
          headers: Headers.of({'cache-control': 'max-stale=180'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Request OnlyIfCached With No Response Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(const []),
        ],
      );

      // With max-stale, we'll return that stale response.
      final request = Request.get(url,
          headers: Headers.of({'cache-control': 'only-if-cached'}));
      final call = cacheClient.newCall(request);
      final response = await call.execute();

      expect(response.code, 504);
      expect(cache.requestCount, 1);
      expect(cache.networkCount, 0);
      expect(cache.hitCount, 0);
    });

    test('Request OnlyIfCached With Full Response Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'date': obtainDate(const Duration(minutes: 0)),
                'cache-control': 'max-age=30',
              },
            ),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          headers: Headers.of({'cache-control': 'only-if-cached'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(cache.requestCount, 2);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 1);
    });

    test('Request OnlyIfCached With Conditional Response Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'date': obtainDate(const Duration(minutes: -1)),
                'cache-control': 'max-age=30',
              },
            ),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          headers: Headers.of({'cache-control': 'only-if-cached'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(response.code, 504);
      expect(cache.requestCount, 2);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);
    });

    test('Request OnlyIfCached With Unhelpful Response Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(body: 'A'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          headers: Headers.of({'cache-control': 'only-if-cached'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(response.code, 504);
      expect(cache.requestCount, 2);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);
    });

    test('Request CacheControl No Cache', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'last-modified': obtainDate(const Duration(seconds: -120)),
                'date': obtainDate(const Duration(seconds: 0)),
                'cache-control': 'max-age=60',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request =
          Request.get(url, headers: Headers.of({'cache-control': 'no-cache'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Request Pragma No Cache', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'last-modified': obtainDate(const Duration(seconds: -120)),
                'date': obtainDate(const Duration(seconds: 0)),
                'cache-control': 'max-age=60',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url, headers: Headers.of({'pragma': 'no-cache'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Authorization Request Fully Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request =
          Request.get(url, headers: Headers.of({'authorization': 'password'}));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Content-Location Does Not Populate Cache', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'content-location': '/bar',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get('$url/foo');
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get('$url/bar');
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Statistics Conditional Cache Miss', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(body: 'B'),
            MockResponse(body: 'C'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(cache.requestCount, 1);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'C');
      await response.body.close();

      expect(cache.requestCount, 3);
      expect(cache.networkCount, 3);
      expect(cache.hitCount, 0);
    });

    test('Statistics Conditional Cache Hit', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(code: io.HttpStatus.notModified),
            MockResponse(code: io.HttpStatus.notModified),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(cache.requestCount, 1);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(cache.requestCount, 3);
      expect(cache.networkCount, 3);
      expect(cache.hitCount, 2);
    });

    test('Statistics Full Cache Hit', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
              },
            ),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(cache.requestCount, 1);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 0);

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(cache.requestCount, 3);
      expect(cache.networkCount, 1);
      expect(cache.hitCount, 2);
    });

    test('Vary Matches Changed Request Header Field', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'vary': 'accept-language',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request =
          Request.get(url, headers: Headers.of({'accept-language': 'en-US'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Vary Matches Unchanged Request Header Field', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'vary': 'accept-language',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Vary Matches Absent Request Header Field', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'vary': 'accept-language',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Vary Matches Added Request Header Field', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'vary': 'accept-language',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Vary Matches Removed Request Header Field', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'vary': 'accept-language',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Vary Fields Are Case Insensitive', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
                'vary': 'ACCEPT-LANGUAGE',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request =
          Request.get(url, headers: Headers.of({'accept-language': 'pt-BR'}));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Vary Multiple Fields With Match', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: HeadersBuilder()
                  .add('cache-control', 'max-age=60')
                  .add('vary', 'accept-language, accept-charset')
                  .add('vary', 'accept-encoding')
                  .build(),
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url,
          headers: Headers.of({
            'accept-language': 'pt-BR',
            'accept-charset': 'utf-8',
            'accept-encoding': 'identity',
          }));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          headers: Headers.of({
            'accept-language': 'pt-BR',
            'accept-charset': 'utf-8',
            'accept-encoding': 'identity',
          }));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Vary Multiple Fields With No Match', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: HeadersBuilder()
                  .add('cache-control', 'max-age=60')
                  .add('vary', 'accept-language, accept-charset')
                  .add('vary', 'accept-encoding')
                  .build(),
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url,
          headers: Headers.of({
            'accept-language': 'en-US',
            'accept-charset': 'utf-8',
            'accept-encoding': 'identity',
          }));
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          headers: Headers.of({
            'accept-language': 'pt-BR',
            'accept-charset': 'utf-8',
            'accept-encoding': 'identity',
          }));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Vary Asterisk', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: HeadersBuilder()
                  .add('cache-control', 'max-age=60')
                  .add('vary', '*')
                  .build(),
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Get Headers Returns Network End To End Headers', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'allow': 'GET, HEAD',
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(
              code: io.HttpStatus.notModified,
              headers: {
                'allow': 'GET, HEAD, PUT',
              },
            ),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('allow'), 'GET, HEAD');

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('allow'), 'GET, HEAD, PUT');
    });

    test('Get Headers Returns Cached Hop By Hop Headers', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'transfer-encoding': 'identity',
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(
              code: io.HttpStatus.notModified,
              headers: {
                'transfer-encoding': 'none',
              },
            ),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('transfer-encoding'), 'identity');

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('transfer-encoding'), 'identity');
    });

    test('Get Headers Deletes Cached 100 Level Warnings', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'warning': '199 test danger',
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(code: io.HttpStatus.notModified),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'), '199 test danger');

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'), null);
    });

    test('Get Headers Retains Cached 200 Level Warnings', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'warning': '299 test danger',
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(code: io.HttpStatus.notModified),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'), '299 test danger');

      request = Request.get(url);
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('warning'), '299 test danger');
    });

    test('Do Not Cache Partial Response', () async {
      await assertNotCached(MockResponse(
        code: io.HttpStatus.partialContent,
        headers: {
          'data': obtainDate(const Duration(hours: 0)),
          'Content-Range': 'bytes 100-100/200',
          'cache-control': 'max-age=60',
        },
      ));
    });

    test('Conditional Hit Updates Cache', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'last-modified': obtainDate(const Duration(seconds: 0)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(
              code: io.HttpStatus.notModified,
              headers: {
                'allow': 'GET, HEAD',
                'cache-control': 'max-age=30',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      // A cache miss writes the cache.
      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('allow'), isNull);

      // A conditional cache hit updates the cache.
      await Future.delayed(const Duration(milliseconds: 500));

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(response.code, 200);
      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('allow'), 'GET, HEAD');
      final updatedTimestamp = response.receivedAt.millisecondsSinceEpoch;

      // A full cache hit reads the cache.
      await Future.delayed(const Duration(milliseconds: 10));

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
      expect(response.headers.first('allow'), 'GET, HEAD');
      expect(response.receivedAt.millisecondsSinceEpoch, updatedTimestamp);
    });

    test('Response Source Header Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'date': obtainDate(const Duration(minutes: 0)),
                'cache-control': 'max-age=30',
              },
            ),
          ]),
        ],
      );

      var request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      request = Request.get(url,
          cacheControl: const CacheControl(onlyIfCached: true));
      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Response Source Header Conditional Cache Fetched', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'date': obtainDate(const Duration(minutes: -31)),
                'cache-control': 'max-age=30',
              },
            ),
            MockResponse(
              body: 'B',
              headers: {
                'date': obtainDate(const Duration(minutes: 0)),
                'cache-control': 'max-age=30',
              },
            ),
          ]),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });

    test('Response Source Header Conditional Cache Not Fetched', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'date': obtainDate(const Duration(minutes: 0)),
                'cache-control': 'max-age=0',
              },
            ),
            MockResponse(code: 304),
          ]),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Response Source Header Fetched', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(body: 'A'),
          ]),
        ],
      );

      final request = Request.get(url);
      final call = cacheClient.newCall(request);
      final response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Clear', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'A',
              headers: {
                'cache-control': 'max-age=60',
              },
            ),
            MockResponse(body: 'B'),
          ]),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      expect(await cache.size(), 138);

      await cache.clear();
      expect(await cache.size(), 0);

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
      expect(await cache.size(), isNonZero);
    });

    test('Combined Cache Headers Can Be Non Ascii', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor([
            MockResponse(
              body: 'abcd',
              headers: {
                'last-modified': obtainDate(const Duration(hours: -1)),
                'cache-control': 'max-age=0',
                'Alpha': 'α',
                'β': 'Beta',
              },
            ),
            MockResponse(
              code: io.HttpStatus.notModified,
              headers: {
                'Transfer-Encoding': 'none',
                'Gamma': 'Γ',
                'Δ': 'Delta',
              },
            ),
          ]),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(response.headers.first('Alpha'), 'α');
      expect(response.headers.first('β'), 'Beta');
      expect(await response.body.data.string(), 'abcd');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(response.headers.first('Alpha'), 'α');
      expect(response.headers.first('β'), 'Beta');
      expect(response.headers.first('Gamma'), 'Γ');
      expect(response.headers.first('Δ'), 'Delta');
      expect(await response.body.data.string(), 'abcd');
      await response.body.close();
    });

    test('Immutable is Cached', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(
                body: 'A',
                headers: {
                  'cache-control': 'immutable, max-age=10',
                },
              ),
              MockResponse(body: 'B'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();
    });

    test('Immutable is Cached After Multiple Calls', () async {
      final cache = Cache(store: store());
      final cacheClient = client.copyWith(
        cache: cache,
        networkInterceptors: [
          MockResponseInterceptor(
            [
              MockResponse(body: 'A'),
              MockResponse(
                body: 'B',
                headers: {
                  'cache-control': 'immutable, max-age=10',
                },
              ),
              MockResponse(body: 'C'),
            ],
          ),
        ],
      );

      final request = Request.get(url);
      var call = cacheClient.newCall(request);
      var response = await call.execute();

      expect(await response.body.data.string(), 'A');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();

      call = cacheClient.newCall(request);
      response = await call.execute();

      expect(await response.body.data.string(), 'B');
      await response.body.close();
    });
  }

  group('MemoryCacheStore', () {
    testCacheStore(() => MemoryCacheStore());
  });

  group('DiskCacheStore', () {
    setUp(() {
      final cacheDir = io.Directory('./.cache');

      if (cacheDir.existsSync()) {
        cacheDir.listSync(recursive: true).forEach((i) => i.deleteSync());
      }
    });

    tearDownAll(() {
      final cacheDir = io.Directory('./.cache');

      if (cacheDir.existsSync()) {
        //cacheDir.listSync(recursive: true).forEach((i) => i.deleteSync());
      }
    });

    testCacheStore(() => DiskCacheStore(io.Directory('./.cache')));
  });
}

String obtainDate(Duration duration) {
  return io.HttpDate.format(DateTime.now().toUtc().add(duration));
}

RequestBody requestBodyOrNull(String method) {
  return (method == 'POST' || method == 'PUT')
      ? RequestBody.string('foo', contentType: MediaType.text)
      : null;
}

ResponseBody gzip(String text) {
  return ResponseBody.bytes(
    io.gzip.encode(utf8.encode(text)),
    compressionType: CompressionType.gzip,
  );
}

class MockResponseInterceptor implements Interceptor {
  final List<Response> responses;
  var _index = 0;

  MockResponseInterceptor(this.responses);

  @override
  Future<Response> intercept(Chain chain) async {
    return responses[_index++].copyWith(request: chain.request);
  }
}

class MockResponse extends Response {
  MockResponse({
    headers,
    CacheControl cacheControl,
    int code,
    body,
  }) : super(
          headers:
              headers is Headers ? headers : Headers.of(headers ?? const {}),
          cacheControl: cacheControl,
          code: code ?? 200,
          redirects: const [],
          cookies: const [],
          body: body is ResponseBody
              ? body
              : ResponseBody.string(
                  body ?? '',
                  contentLength: body?.length ?? 0,
                  contentType: MediaType.text,
                ),
          sentAt: DateTime.now(),
          receivedAt: DateTime.now(),
          spentMilliseconds: 0,
          totalMilliseconds: 0,
        );

  MockResponse copyMockWith({
    headers,
    CacheControl cacheControl,
    int code,
    body,
  }) {
    return MockResponse(
      headers: headers ?? this.headers.toMap(),
      cacheControl: cacheControl ?? this.cacheControl,
      code: code ?? this.code,
      body: body ?? this.body,
    );
  }
}
