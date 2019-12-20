import 'package:restio/src/cache/cache_control.dart';
import 'package:test/test.dart';

void main() {
  test('Parse no-store', () {
    final cacheControl = CacheControl.parse('no-store');
    expect(cacheControl.noStore, true);
  });

  test('Parse no-cache', () {
    final cacheControl = CacheControl.parse('no-cache');
    expect(cacheControl.noCache, true);
  });

  test('Parse must-revalidate', () {
    final cacheControl = CacheControl.parse('must-revalidate');
    expect(cacheControl.mustRevalidate, true);
  });

  test('Parse max-age', () {
    var cacheControl = CacheControl.parse('max-age=12345678');
    expect(cacheControl.maxAge, const Duration(seconds: 12345678));
    cacheControl = CacheControl.parse('max-age="12345678\"');
    expect(cacheControl.maxAge, const Duration(seconds: 12345678));
  });

  test('Parse public', () {
    final cacheControl = CacheControl.parse('public, max-age=60');
    expect(cacheControl.isPublic, true);
    expect(cacheControl.isPrivate, false);
    expect(cacheControl.maxAge, const Duration(seconds: 60));
  });

  test('Parse private', () {
    final cacheControl = CacheControl.parse('private');
    expect(cacheControl.isPublic, false);
    expect(cacheControl.isPrivate, true);
  });

  test('Parse no-transform', () {
    final cacheControl = CacheControl.parse('no-transform');
    expect(cacheControl.noTransform, true);
  });

  test('Parse all parameters', () {
    final cacheControl = CacheControl.parse(
        'private, public,max-age="12345678", must-revalidate,no-cache,no-transform, no-store, immutable, s-maxage=60');
    expect(cacheControl.isPrivate, true);
    expect(cacheControl.isPublic, true);
    expect(cacheControl.maxAge, const Duration(seconds: 12345678));
    expect(cacheControl.mustRevalidate, true);
    expect(cacheControl.noCache, true);
    expect(cacheControl.noStore, true);
    expect(cacheControl.immutable, true);
    expect(cacheControl.noTransform, true);
  });

  test('Parse empty', () {
    final cacheControl = CacheControl.parse('');
    expect(cacheControl, null);
  });
}
