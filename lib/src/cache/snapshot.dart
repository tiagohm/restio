class Snapshot {
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
}
