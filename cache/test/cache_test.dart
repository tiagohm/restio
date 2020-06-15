import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio_cache/restio_cache.dart';
import 'package:test/test.dart';

import 'cache_tests.dart';
import 'fernet.dart';

final client = Restio(
  interceptors: [
    // LogInterceptor(),
  ],
);

final cacheDir = Directory('./.cache');

void main() {
  setUp(() {
    cacheDir.listSync(recursive: true).forEach((i) => i.deleteSync());
  });

  group('LruCacheStore:Memory', () {
    testCache(client, () async => LruCacheStore.memory());
  });

  group('LruCacheStore:Local', () {
    testCache(client, () async => LruCacheStore.local(cacheDir.path));
  });

  group('LruCacheStore:Encrypted', () {
    testCache(client, () async {
      return LruCacheStore.local(
        cacheDir.path,
        decrypt: decrypt,
        encrypt: encrypt,
      );
    });
  });

  group('Restio', () {
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

    test('Correct Timestamp When Use Cache & Redirects', () async {
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
  });
}
