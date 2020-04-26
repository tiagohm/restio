@Timeout(Duration(days: 1))

import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

import 'cache_tests.dart';

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

  group('Cache With MemoryCacheStore', () {
    testCache(client, () async => MemoryCacheStore());
  });

  group('Cache With DiskCacheStore', () {
    testCache(client, () async => DiskCacheStore(cacheDir));
  });

  group('Cache With DiskLruCacheStore', () {
    testCache(client, () async => DiskLruCacheStore.open(cacheDir));
  });
}