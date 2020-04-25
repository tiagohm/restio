import 'package:restio/src/core/cache/editor.dart';
import 'package:restio/src/core/cache/snapshot.dart';

abstract class CacheStore {
  static const anySequenceNumber = -1;

  Future<Snapshot> get(String key);

  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]);

  Future<bool> remove(String key);

  Future<bool> clear();

  Future<int> size();
}
