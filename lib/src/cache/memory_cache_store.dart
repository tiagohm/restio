import 'dart:async';

import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/snapshot.dart';

class MemoryCacheStore implements CacheStore {
  final _cache = <String, Map<int, List<int>>>{};

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]) async {
    if (!_cache.containsKey(key)) {
      _cache[key] = <int, List<int>>{};
    }

    return _Editor(_cache[key]);
  }

  @override
  Future<Snapshot> get(String key) async {
    if (!_cache.containsKey(key)) {
      return null;
    }

    return Snapshot(
      key,
      CacheStore.anySequenceNumber,
      _sources(key),
      _lengths(key),
    );
  }

  List<Stream<List<int>>> _sources(String key) {
    final data = _cache[key];

    return [
      Stream.value(data[0] ?? const []),
      Stream.value(data[1] ?? const []),
    ];
  }

  List<int> _lengths(String key) {
    final data = _cache[key];

    return [
      data[0]?.length ?? 0,
      data[1]?.length ?? 1,
    ];
  }

  @override
  Future<bool> remove(String key) async {
    return _cache.remove(key) != null;
  }
}

class _Editor implements Editor {
  var _done = false;
  final Map<int, List<int>> cache;

  _Editor(this.cache);

  @override
  void abort() {
    if (_done) {
      throw AssertionError();
    }

    _done = true;
  }

  @override
  void commit() {
    if (_done) {
      throw AssertionError();
    }

    _done = true;
  }

  @override
  StreamSink<List<int>> newSink(int index) {
    if (_done) {
      throw AssertionError();
    }

    if (!cache.containsKey(index)) {
      cache[index] = [];
    }

    return _SourceSink(cache[index]);
  }

  @override
  Stream<List<int>> newSource(int index) {
    if (_done) {
      throw AssertionError();
    }

    if (!cache.containsKey(index)) {
      cache[index] = [];
    }

    return Stream.value(cache[index]);
  }
}

class _SourceSink extends StreamSink<List<int>> {
  final List<int> data;
  final _completer = Completer<List<int>>();
  var _closed = false;

  _SourceSink(this.data);

  @override
  void add(List<int> event) {
    if (_closed) {
      throw AssertionError('Sink is closed');
    }

    data.addAll(event);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    if (_closed) {
      throw AssertionError('Sink is closed');
    }

    _closed = true;
    _completer.completeError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    if (_closed) {
      throw AssertionError('Sink is closed');
    }

    return stream.listen(data.addAll).asFuture();
  }

  @override
  Future close() async {
    if (_closed) {
      throw AssertionError('Sink is closed');
    }

    _closed = true;
    _completer.complete(data);
  }

  @override
  Future get done => _completer.future;
}
