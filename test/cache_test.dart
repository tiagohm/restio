import 'dart:io';

import 'package:restio/restio.dart';
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
}
