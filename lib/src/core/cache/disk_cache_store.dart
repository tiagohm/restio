import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:restio/src/common/file_stream_sink.dart';
import 'package:restio/src/core/cache/cache_store.dart';
import 'package:restio/src/core/cache/editor.dart';
import 'package:restio/src/core/cache/snapshot.dart';

class DiskCacheStore implements CacheStore {
  static final _keyPattern = RegExp(r'^[a-z0-9_-]{1,120}$');

  int _maxSize;
  final Directory directory;
  final int valueCount = 2;
  int _size = 0;
  final _cache = <String, _Entry>{};
  int _nextSequenceNumber = 0;
  var _isClosed = false;

  DiskCacheStore(
    this.directory, {
    // this.valueCount = 2,
    int maxSize = 10 * 1024 * 1024,
  })  : assert(directory != null),
        // assert(valueCount != null && valueCount > 0),
        assert(maxSize != null && maxSize > 0),
        _maxSize = maxSize;

  int get maxSize => _maxSize;

  Future<void> increaseMaxSize(int value) async {
    _maxSize = value;
    await cleanup();
  }

  Future<void> cleanup() async {
    // Closed.
    if (_isClosed) {
      return;
    }

    _trimToSize();
  }

  @override
  Future<void> clear() async {
    _checkNotClosed();

    final entries = List.of(_cache.values);

    for (final entry in entries) {
      await entry.editor?.abort();
    }

    _trimToSize(0);
  }

  @override
  Future<Editor> edit(
    String key, [
    int expectedSequenceNumber = -1,
  ]) async {
    _checkNotClosed();
    _validateKey(key);

    var entry = _cache[key];

    // Snapshot is stale.
    if (expectedSequenceNumber != CacheStore.anySequenceNumber &&
        (entry == null || entry.sequenceNumber != expectedSequenceNumber)) {
      return null;
    }

    if (entry == null) {
      entry = _Entry(directory, key, valueCount);
      _cache[key] = entry;
    }
    // Another edit is in progress.
    else if (entry.editor != null) {
      return null;
    }

    final editor = _Editor(this, entry, valueCount);
    entry.editor = editor;
    return editor;
  }

  void _checkNotClosed() {
    if (_isClosed) {
      throw StateError('Cache is closed');
    }
  }

  void _validateKey(String key) {
    if (!_keyPattern.hasMatch(key)) {
      throw ArgumentError('Key is invalid: $key');
    }
  }

  Future<void> _completeEdit(
    _Editor editor,
    bool success,
  ) async {
    final entry = editor.entry;

    if (entry.editor != editor) {
      throw StateError('Wrong editor for key ${entry.key}');
    }

    if (success && !entry.readable) {
      for (var i = 0; i < valueCount; i++) {
        if (!editor.written[i]) {
          await editor.abort();

          throw StateError(
            "Newly created entry didn't create value for index $i",
          );
        }
      }
    }

    for (var i = 0; i < valueCount; i++) {
      final dirty = entry.getDirtyFile(i);

      if (success) {
        if (dirty.existsSync()) {
          final clean = entry.getCleanFile(i);

          dirty.renameSync(clean.path);

          final oldLength = entry.lengths[i];
          final newLength = clean.lengthSync();

          entry.lengths[i] = newLength;

          _size = _size - oldLength + newLength;
        }
      } else {
        if (dirty.existsSync()) {
          dirty.deleteSync();
        }
      }
    }

    entry.editor = null;

    if (entry.readable || success) {
      entry.readable = true;

      if (success) {
        entry.sequenceNumber = _nextSequenceNumber++;
      }
    } else {
      _cache.remove(entry.key);
    }

    if (_size > maxSize) {
      await cleanup();
    }
  }

  @override
  Future<Snapshot> get(String key) async {
    _checkNotClosed();
    _validateKey(key);

    final entry = _cache[key];

    if (entry == null) {
      return null;
    }

    if (!entry.readable) {
      return null;
    }

    final streams = <Stream<List<int>>>[];

    for (var i = 0; i < valueCount; i++) {
      try {
        final s = Stream.value(entry.getCleanFile(i).readAsBytesSync())
            .cast<List<int>>();
        streams.add(s);
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        return null;
      }
    }

    return _Snapshot(this, key, entry.sequenceNumber, streams, entry.lengths);
  }

  @override
  Future<bool> remove(String key) async {
    _checkNotClosed();
    _validateKey(key);

    final entry = _cache[key];

    if (entry == null || entry.editor != null) {
      return false;
    }

    for (var i = 0; i < valueCount; i++) {
      final file = entry.getCleanFile(i);

      if (file.existsSync()) {
        file.deleteSync();
      }

      _size -= entry.lengths[i];

      entry.lengths[i] = 0;
    }

    _cache.remove(key);

    return true;
  }

  @override
  Future<int> size() async {
    return _cache.values.fold<int>(0, (a, b) => a + b.length);
  }

  @override
  Future<void> close() async {
    if (_isClosed) {
      return;
    }

    await clear();

    _isClosed = true;
  }

  @override
  bool get isClosed => _isClosed;

  void _trimToSize([int forcedSize]) {
    final maxSize = forcedSize ?? this.maxSize;

    while (_size > maxSize) {
      final first = _cache.isEmpty ? null : _cache.values.first;
      remove(first.key);
    }
  }
}

class _Entry {
  final String key;
  final List<int> lengths;
  final int valueCount;
  final List<File> _cleanFiles;
  final List<File> _dirtyFiles;

  var readable = false;
  _Editor editor;
  var sequenceNumber = 0;

  _Entry(Directory directory, this.key, this.valueCount)
      : lengths = List.filled(valueCount, 0),
        _cleanFiles = List.generate(
            valueCount, (i) => File(join(directory.path, '$key.$i'))),
        _dirtyFiles = List.generate(
            valueCount, (i) => File(join(directory.path, '$key.$i.tmp')));

  void setLengths(List<String> lengths) {
    if (lengths.length != valueCount) {
      throw ArgumentError('lengths');
    }

    for (var i = 0; i < lengths.length; i++) {
      this.lengths[i] = int.parse(lengths[i]);
    }
  }

  File getCleanFile(int i) {
    return _cleanFiles[i];
  }

  File getDirtyFile(int i) {
    return _dirtyFiles[i];
  }

  int get length => lengths.fold(0, (a, b) => a + b);
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
  final _Entry entry;
  final List<bool> written;
  bool hasErrors = false;
  bool committed = false;
  final DiskCacheStore cache;

  _Editor(this.cache, this.entry, int valueCount)
      : written = entry.readable ? null : List.filled(valueCount, false);

  @override
  Future<void> abort() {
    return cache._completeEdit(this, false);
  }

  @override
  Future<void> commit() async {
    if (hasErrors) {
      await cache._completeEdit(this, false);
      // The previous entry is stale.
      await cache.remove(entry.key);
    } else {
      await cache._completeEdit(this, true);
    }

    committed = true;
  }

  @override
  StreamSink<List<int>> newSink(int index) {
    if (entry.editor != this) {
      throw StateError('Wrong editor for index $index');
    }

    if (!entry.readable) {
      written[index] = true;
    }

    final dirtyFile = entry.getDirtyFile(index);

    return FileStreamSink(dirtyFile, onError: () => hasErrors = true);
  }

  @override
  Stream<List<int>> newSource(int index) {
    if (entry.editor != this) {
      throw StateError('Wrong editor for index $index');
    }

    if (!entry.readable) {
      return null;
    }

    final dirtyFile = entry.getDirtyFile(index);

    return Stream.value(dirtyFile.readAsBytesSync()).cast<List<int>>();
  }
}
