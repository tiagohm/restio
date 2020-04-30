@Timeout(Duration(days: 1))

import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

import 'cache_tests.dart';

const client = Restio(
  interceptors: [
    // LogInterceptor(),
  ],
);

final cacheDir = Directory('./.cache');

void main() {
  setUp(() {
    cacheDir.listSync(recursive: true).forEach((i) => i.deleteSync());
  });

  group('LruCacheStore In Memory', () {
    testCache(client, () async => LruCacheStore.memory());
  });

  group('Local LruCacheStore', () {
    testCache(client, () async => LruCacheStore.local(cacheDir.path));
  });
}
