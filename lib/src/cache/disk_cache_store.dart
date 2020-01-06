import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:restio/src/cache/cache.dart';
import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/snapshot.dart';
import 'package:restio/src/cache/source_sink.dart';

class DiskCacheStore implements CacheStore {
  final Directory directory;
  final int valueCount;
  final _cache = <String, Map<int, List<int>>>{};

  DiskCacheStore._(
    this.directory,
    this.valueCount,
  ) : assert(directory != null) {
    _populateCache();
  }

  factory DiskCacheStore.create(Directory directory) {
    return DiskCacheStore._(directory, Cache.entryCount);
  }

  void _populateCache() {
    for (final item in directory.listSync()) {
      if (item is File) {
        final filename = path.basename(item.path);
        final nameAndExtension = filename.split('.');

        if (nameAndExtension?.length == 2) {
          final key = nameAndExtension[0];
          final index = int.tryParse(nameAndExtension[1]);

          if (index != null) {
            try {
              final bytes = item.readAsBytesSync();
              _cache.putIfAbsent(key, () => <int, List<int>>{})[index] = bytes;
            } catch (e) {
              // nada.
            }
          }
        }
      }
    }
  }

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]) async {
    if (!_cache.containsKey(key)) {
      _cache[key] = <int, List<int>>{};
    }

    return _Editor(_cache[key], key, directory, valueCount);
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

    for (final item in directory.listSync()) {
      try {
        item.deleteSync();
      } catch (e) {
        return false;
      }
    }

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
  String key;
  final List<File> files;
  final Map<int, List<int>> cache;
  var _done = false;

  _Editor(
    this.cache,
    this.key,
    Directory directory,
    int valueCount,
  ) : files = List<File>.generate(valueCount, (index) {
          return File(path.join(directory.path, '$key.$index'));
        });

  @override
  void abort() {
    if (_done) {
      throw StateError('Editor is closed');
    }

    cache.clear();
    files[0].writeAsBytes(cache[0]);
    files[1].writeAsBytes(cache[1]);

    _done = true;
  }

  @override
  void commit() {
    if (_done) {
      throw StateError('Editor is closed');
    }

    files[0].writeAsBytes(cache[0]);
    files[1].writeAsBytes(cache[1]);

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
