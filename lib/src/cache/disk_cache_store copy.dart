import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:restio/src/cache/cache.dart';
import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/snapshot.dart';

class DiskCacheStore implements CacheStore {
  final Directory directory;
  final int valueCount;

  DiskCacheStore._(
    this.directory,
    this.valueCount,
  ) : assert(directory != null);

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber,
  ]) async {
    final entry = _Entry(key, directory, valueCount);
    return _Editor(entry);
  }

  @override
  Future<Snapshot> get(String key) async {
    final entry = _Entry(key, directory, valueCount);
    return entry.snapshot();
  }

  @override
  Future<bool> remove(String key) {
    final entry = _Entry(key, directory, valueCount);
    return entry.remove();
  }

  factory DiskCacheStore.create(Directory directory) {
    return DiskCacheStore._(directory, Cache.entryCount);
  }

  @override
  Future<bool> clear() async {
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

    for (final item in directory.listSync()) {
      if (item is File) {
        total += item.lengthSync();
      }
    }

    return total;
  }
}

class _Entry {
  final String key;
  final List<File> cacheFiles;
  final List<File> dirtyFiles;

  _Entry(
    this.key,
    Directory directory,
    int valueCount,
  )   : cacheFiles = List<File>.generate(valueCount, (index) {
          return File(path.join(directory.path, '$key.$index'));
        }),
        dirtyFiles = List<File>.generate(valueCount, (index) {
          return File(path.join(directory.path, '$key.$index.dirty'));
        });

  Snapshot snapshot() {
    for (var i = 0; i < cacheFiles.length; i++) {
      if (!cacheFiles[i].existsSync() && !dirtyFiles[i].existsSync()) {
        return null;
      }
    }

    final sources = [
      for (final cacheFile in cacheFiles) cacheFile.openRead(),
    ];

    final lengths = [
      for (final cacheFile in cacheFiles)
        cacheFile.existsSync() ? cacheFile.lengthSync() : 0,
    ];

    return Snapshot(key, CacheStore.anySequenceNumber, sources, lengths);
  }

  Future<bool> remove() async {
    for (final cacheFile in cacheFiles) {
      if (cacheFile.existsSync()) {
        cacheFile.deleteSync();
      }
    }

    return true;
  }

  int size() {
    var total = 0;

    for (final cacheFile in cacheFiles) {
      total += cacheFile.lengthSync();
    }

    return total;
  }
}

class _Editor implements Editor {
  final List<File> cleanFiles;
  final List<File> dirtyFiles;
  var _done = false;

  _Editor(
    _Entry entry,
  )   : cleanFiles = entry.cacheFiles,
        dirtyFiles = [
          for (final cacheFile in entry.cacheFiles)
            File(path.join(
              path.dirname(cacheFile.path),
              '${path.basename(cacheFile.path)}.dirty',
            )),
        ];

  @override
  StreamSink<List<int>> newSink(int index) {
    if (_done) {
      throw StateError('Editor is closed');
    }

    final dirtyFile = dirtyFiles[index];

    if (dirtyFile.existsSync()) {
      dirtyFile.deleteSync();
    }

    dirtyFile.createSync(recursive: true);

    return dirtyFile.openWrite(mode: FileMode.write, encoding: utf8);
  }

  @override
  Stream<List<int>> newSource(int index) {
    if (!_done) {
      throw StateError('Editor is closed');
    }

    final cleanFile = cleanFiles[index];

    if (!cleanFile.existsSync()) {
      throw StateError('File is not exists');
    }

    return cleanFile.openRead();
  }

  @override
  void commit() {
    if (_done) {
      throw StateError('Editor is closed');
    }

    _complete(true);
    _done = true;
  }

  @override
  void abort() {
    if (_done) {
      throw StateError('Editor is closed');
    }

    _complete(false);
    _done = true;
  }

  void _detach() {
    for (final dirtyFile in dirtyFiles) {
      if (dirtyFile.existsSync()) {
        dirtyFile.deleteSync();
      }
    }
  }

  void _complete(bool success) {
    if (success) {
      for (var i = 0; i < dirtyFiles.length; i++) {
        final dirtyFile = dirtyFiles[i];

        if (dirtyFile.existsSync()) {
          final cleanFile = cleanFiles[i];

          if (cleanFile.existsSync()) {
            cleanFile.deleteSync();
          }

          dirtyFile.renameSync(cleanFile.path);
        }
      }
    } else {
      _detach();
    }
  }
}
