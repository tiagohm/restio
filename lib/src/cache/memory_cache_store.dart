import 'dart:async';

import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/snapshot.dart';
import 'package:restio/src/cache/source_sink.dart';

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

  @override
  Future<bool> clear() async {
    _cache.clear();
    return true;
  }

  @override
  Future<int> size() async {
    var total = 0;

    _cache.forEach((key, source) {
      source.forEach((index, data) {
        total += data.length;
      });
    });

    return total;
  }
}

class _Editor implements Editor {
  var _done = false;
  final Map<int, List<int>> cache;

  _Editor(this.cache);

  @override
  void abort() {
    if (_done) {
      throw StateError('Editor is closed');
    }

    cache.clear();
    _done = true;
  }

  @override
  void commit() {
    if (_done) {
      throw StateError('Editor is closed');
    }

    _done = true;
  }

  @override
  StreamSink<List<int>> newSink(int index) {
    if (_done) {
      throw StateError('Editor is closed');
    }

    cache[index] = [];

    return SourceSink(cache[index]);
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
