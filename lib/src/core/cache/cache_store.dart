import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/cache/editor.dart';
import 'package:restio/src/core/cache/snapshot.dart';

abstract class CacheStore implements Closeable {
  static const anySequenceNumber = -1;

  Future<Snapshot> get(String key);

  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]);

  Future<bool> remove(String key);

  Future<void> clear();

  Future<int> size();

  bool get isClosed;
}
