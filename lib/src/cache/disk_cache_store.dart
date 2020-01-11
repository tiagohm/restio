import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/snapshot.dart';

class DiskCacheStore implements CacheStore {
  final Directory directory;
  final _cache = <String, Map<int, File>>{};
  var _initialized = false;

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
    _initialize(key);

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
    _initialize(key);

    final data = _cache[key];

    return [
      data[0].openRead(),
      data[1].openRead(),
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
    if (_cache[key][0].existsSync()) {
      _cache[key][0].deleteSync();
    }

    if (_cache[key][1].existsSync()) {
      _cache[key][1].deleteSync();
    }

    _cache.remove(key);

    return true;
  }

  static void _deleteFileSystemEntity(FileSystemEntity entity) {
    entity.deleteSync(recursive: true);
  }

  @override
  Future<bool> clear() async {
    try {
      directory.listSync().forEach(_deleteFileSystemEntity);
      _cache.clear();
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<int> size() async {
    var total = 0;

    _cache.forEach((key, source) {
      source.forEach((index, file) {
        total += file.lengthSync();
      });
    });

    return total;
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

    return _FileSink(cache[index].openWrite(mode: FileMode.write));
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

class _FileSink extends StreamSink<List<int>> {
  final IOSink sink;

  _FileSink(this.sink);

  @override
  void add(List<int> event) {
    sink.add(event);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    sink.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return sink.addStream(stream);
  }

  @override
  Future close() async {
    try {
      await sink.flush();
    } catch (e) {
      // nada.
    }

    return sink.close();
  }

  @override
  Future get done => sink.done;
}
