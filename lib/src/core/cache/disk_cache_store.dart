import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:restio/src/common/file_stream_sink.dart';
import 'package:restio/src/core/cache/cache_store.dart';
import 'package:restio/src/core/cache/editor.dart';
import 'package:restio/src/core/cache/snapshot.dart';

class DiskCacheStore implements CacheStore {
  final Directory directory;
  final _cache = <String, Map<int, File>>{};
  var _initialized = false;
  var _closed = false;

  DiskCacheStore(this.directory);

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber = -1,
  ]) async {
    if (!_cache.containsKey(key)) {
      _cache[key] = <int, File>{};
    }

    return _Editor(this, key, _cache[key]);
  }

  void _checkNotClosed() {
    if (_closed) {
      throw StateError('Cache is closed');
    }
  }

  void _initialize(String key) {
    if (_initialized) {
      return;
    }

    final f0 = File(join(directory.path, '$key.0'));
    final f1 = File(join(directory.path, '$key.1'));

    // Remove ambos, se um dos arquivos não existir.
    if (!f0.existsSync() || !f1.existsSync()) {
      if (f0.existsSync()) {
        f0.deleteSync();
      }

      if (f1.existsSync()) {
        f1.deleteSync();
      }
    } else {
      _cache[key] = <int, File>{};
      _cache[key][0] = f0;
      _cache[key][1] = f1;
    }

    _initialized = true;
  }

  @override
  Future<Snapshot> get(String key) async {
    _checkNotClosed();

    _initialize(key);

    if (!_cache.containsKey(key)) {
      return null;
    }

    return _Snapshot(
      this,
      key,
      CacheStore.anySequenceNumber,
      _sources(key),
      _lengths(key),
    );
  }

  List<Stream<List<int>>> _sources(String key) {
    _initialize(key);

    final data = _cache[key];

    return [
      Stream.value(data[0].readAsBytesSync()),
      Stream.value(data[1].readAsBytesSync()),
      // data[0].openRead(),
      // data[1].openRead(),
    ];
  }

  List<int> _lengths(String key) {
    _initialize(key);

    final data = _cache[key];

    return [
      data[0].lengthSync(),
      data[1].lengthSync(),
    ];
  }

  @override
  Future<bool> remove(String key) async {
    _checkNotClosed();

    if (_cache[key] != null &&
        _cache[key].containsKey(0) &&
        _cache[key][0].existsSync()) {
      _cache[key][0].deleteSync();
    }

    if (_cache[key] != null &&
        _cache[key].containsKey(1) &&
        _cache[key][1].existsSync()) {
      _cache[key][1].deleteSync();
    }

    _cache.remove(key);

    return true;
  }

  static void _deleteFile(FileSystemEntity entity) {
    entity.deleteSync(recursive: true);
  }

  @override
  Future<void> clear() async {
    _checkNotClosed();

    try {
      directory.listSync().forEach(_deleteFile);
      _cache.clear();
    } catch (e) {
      // nada.
    }
  }

  @override
  Future<int> size() async {
    _checkNotClosed();

    var total = 0;

    _cache.forEach((key, source) {
      source.forEach((index, file) {
        total += file.lengthSync();
      });
    });

    return total;
  }

  @override
  Future<void> close() async {
    _closed = true;
  }

  @override
  bool get isClosed => _closed;
}

class _Snapshot extends Snapshot {
  final CacheStore store;

  _Snapshot(
    this.store,
    String key,
    int sequenceNumber,
    List<Stream<List<int>>> sources,
    List<int> lengths,
  ) : super(key, sequenceNumber, sources, lengths);

  @override
  Future<Editor> edit() {
    return store.edit(key, sequenceNumber);
  }
}

class _Editor implements Editor {
  final DiskCacheStore store;
  final String key;
  final Map<int, File> cache;
  var _done = false;

  _Editor(this.store, this.key, this.cache);

  @override
  Future<void> abort() async {
    if (_done) {
      throw StateError('Editor is closed');
    }

    cache.clear();
    _done = true;
  }

  @override
  Future<void> commit() async {
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

    if (!cache.containsKey(index)) {
      cache[index] = File(join(store.directory.path, '$key.$index'));
    }

    if (!cache[index].existsSync()) {
      cache[index].createSync();
    }

    return FileStreamSink(cache[index]);
  }

  @override
  Stream<List<int>> newSource(int index) {
    if (_done) {
      throw AssertionError();
    }

    if (!cache.containsKey(index)) {
      cache[index] = File(join(store.directory.path, '$key.$index'));
    }

    if (!cache[index].existsSync()) {
      cache[index].createSync();
    }

    return cache[index].openRead();
  }
}
