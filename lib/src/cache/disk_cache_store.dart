import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/snapshot.dart';

class DiskCacheStore implements CacheStore {
  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]) {
    // TODO:
    throw UnimplementedError();
  }

  @override
  Future<Snapshot> get(String key) {
    // TODO:
    throw UnimplementedError();
  }

  @override
  Future<bool> remove(String key) {
    // TODO:
    throw UnimplementedError();
  }
}
