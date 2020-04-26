import 'package:restio/restio.dart';
import 'package:restio/src/common/closeable.dart';

abstract class Snapshot implements Closeable {
  final String key;
  final int sequenceNumber;
  final List<Stream<List<int>>> _sources;
  final List<int> _lengths;

  Snapshot(
    this.key,
    this.sequenceNumber,
    this._sources,
    this._lengths,
  );

  Stream<List<int>> source(int index) {
    return _sources[index];
  }

  int length(int index) {
    return _lengths[index];
  }

  int size() {
    return _lengths.isEmpty ? 0 : _lengths.reduce((a, b) => a + b);
  }

  Future<Editor> edit();

  @override
  Future<void> close() async {
    for (final stream in _sources) {
      if (stream is Closeable) {
        await (stream as Closeable).close();
      }
    }
  }
}
