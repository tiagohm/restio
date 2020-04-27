import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';
import 'package:path/path.dart' as path;
import 'package:restio/src/common/file_stream_sink.dart';
import 'package:restio/src/common/strict_line_splitter.dart';
import 'package:restio/src/core/cache/cache_store.dart';
import 'package:restio/src/core/cache/editor.dart';
import 'package:restio/src/core/cache/snapshot.dart';

// https://github.com/JakeWharton/DiskLruCache/blob/master/src/main/java/com/jakewharton/disklrucache/DiskLruCache.java

class LruCacheStore implements CacheStore {
  static const journalFile = 'journal';
  static const journalFileTmp = 'journal.tmp';
  static const journalFileBackup = 'journal.bkp';
  static const magic = 'tiagohm.restio.LruCacheStore';
  static const version = '1';
  static final _keyPattern = RegExp(r'^[a-z0-9_-]{1,120}$');
  static const _clean = 'CLEAN';
  static const _dirty = 'DIRTY';
  static const _remove = 'REMOVE';
  static const _read = 'READ';

  final File _journalFile;
  final File _journalFileTmp;
  final File _journalFileBackup;
  final int appVersion;
  int _maxSize;
  final int valueCount;
  int _size = 0;
  IOSink _journalWriter;
  final _lruEntries = <String, _Entry>{};
  int _redundantOpCount = 0;
  int _nextSequenceNumber = 0;
  final String directory;
  final FileSystem fileSystem;

  LruCacheStore._(
    this.fileSystem,
    this.directory,
    this.appVersion,
    this.valueCount,
    this._maxSize,
  )   : _journalFile = fileSystem.file(path.join(directory, journalFile)),
        _journalFileTmp = fileSystem.file(path.join(directory, journalFileTmp)),
        _journalFileBackup =
            fileSystem.file(path.join(directory, journalFileBackup));

  static Future<LruCacheStore> open(
    FileSystem fileSystem,
    String directory, {
    int maxSize = 10 * 1024 * 1024, // 10 MiB
  }) async {
    assert(maxSize != null && maxSize > 0);

    final store = LruCacheStore._(fileSystem, directory, 1, 2, maxSize);

    if (store._journalFileBackup.existsSync()) {
      if (store._journalFile.existsSync()) {
        store._journalFileBackup.deleteSync();
      } else {
        store._journalFileBackup.renameSync(store._journalFile.path);
      }
    }

    if (store._journalFile.existsSync()) {
      try {
        await store._readJournal();
        store._processJournal();
        return store;
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);

        fileSystem
            .directory(directory)
            .listSync()
            .forEach((i) => i.deleteSync());
      }
    }

    await store._rebuildJournal();

    return store;
  }

  static Future<LruCacheStore> memory({
    int maxSize = 10 * 1024 * 1024, // 10 MiB
  }) {
    return open(MemoryFileSystem(), '/', maxSize: maxSize);
  }

  static Future<LruCacheStore> local(
    String directory, {
    int maxSize = 10 * 1024 * 1024, // 10 MiB
  }) {
    return open(const LocalFileSystem(), directory, maxSize: maxSize);
  }

  int get maxSize => _maxSize;

  Future<void> increaseMaxSize(int value) async {
    _maxSize = value;
    await cleanup();
  }

  Future<void> _readJournal() async {
    final splitter = StrictLineSplitter(includeUnterminatedLine: false);

    final lines = await _journalFile
        .openRead()
        .transform(utf8.decoder)
        .transform(splitter)
        .toList();

    // Magic.
    if (magic != lines[0]) {
      throw FileSystemException('Magic is invalid: ${lines[0]}');
    }
    // Version.
    if (version != lines[1]) {
      throw FileSystemException('Version is invalid: ${lines[1]}');
    }
    // App Version.
    if (appVersion != int.tryParse(lines[2])) {
      throw FileSystemException('App Version is invalid: ${lines[2]}');
    }
    // Value Count.
    if (valueCount != int.tryParse(lines[3])) {
      throw FileSystemException('Value Count is invalid: ${lines[3]}');
    }
    // Blank.
    if (lines[4].isNotEmpty) {
      throw const FileSystemException('Line 5 is not empty');
    }

    var lineCount = 5;
    var error = false;

    while (lineCount < lines.length) {
      try {
        _readJournalLine(lines[lineCount++]);
      } on FileSystemException {
        rethrow;
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        error = true;
        break;
      }
    }

    _redundantOpCount = (lineCount - 5) - _lruEntries.length;

    if (splitter.hasUnterminatedLine || error) {
      await _rebuildJournal();
    } else {
      _journalWriter = _journalFile.openWrite(mode: FileMode.append);
    }
  }

  void _readJournalLine(String line) {
    final firstSpace = line.indexOf(' ');

    if (firstSpace == -1) {
      throw FileSystemException('Unexpected journal line: $line');
    }

    final keyBegin = firstSpace + 1;
    final secondSpace = line.indexOf(' ', keyBegin);
    String key;

    if (secondSpace == -1) {
      key = line.substring(keyBegin);

      if (firstSpace == _remove.length && line.startsWith(_remove)) {
        _lruEntries.remove(key);
        return;
      }
    } else {
      key = line.substring(keyBegin, secondSpace);
    }

    var entry = _lruEntries[key];

    if (entry == null) {
      entry = _Entry(fileSystem, directory, key, valueCount);
      _lruEntries[key] = entry;
    }

    if (secondSpace != -1 &&
        firstSpace == _clean.length &&
        line.startsWith(_clean)) {
      final parts = line.substring(secondSpace + 1).split(' ');
      entry.readable = true;
      entry.editor = null;

      try {
        entry.setLengths(parts);
      } catch (e) {
        throw FileSystemException('Unexpected journal line: $line');
      }
    } else if (secondSpace == -1 &&
        firstSpace == _dirty.length &&
        line.startsWith(_dirty)) {
      entry.editor = _Editor(this, entry, valueCount);
    } else if (secondSpace == -1 &&
        firstSpace == _read.length &&
        line.startsWith(_read)) {
      // This work was already done by calling _lruEntries[].
    } else {
      throw FileSystemException('Unexpected journal line: $line');
    }
  }

  void _processJournal() {
    if (_journalFileTmp.existsSync()) {
      _journalFileTmp.deleteSync();
    }

    final entriesToRemove = <String>[];

    _lruEntries.forEach((key, entry) {
      if (entry.editor == null) {
        for (var t = 0; t < valueCount; t++) {
          _size += entry.lengths[t];
        }
      } else {
        entry.editor = null;

        for (var t = 0; t < valueCount; t++) {
          final cleanFile = entry.getCleanFile(t);
          final dirtyFile = entry.getDirtyFile(t);

          if (cleanFile.existsSync()) {
            cleanFile.deleteSync();
          }

          if (dirtyFile.existsSync()) {
            dirtyFile.deleteSync();
          }

          entriesToRemove.add(key);
        }
      }
    });

    entriesToRemove.forEach(_lruEntries.remove);
  }

  Future<void> _rebuildJournal() async {
    await _journalWriter?.close();

    final writer = _journalFileTmp.openWrite();

    writer.writeln(magic);
    writer.writeln(version);
    writer.writeln(appVersion);
    writer.writeln(valueCount);
    writer.writeln();

    for (final entry in _lruEntries.values) {
      if (entry.editor != null) {
        writer.writeln('$_dirty ${entry.key}');
      } else {
        writer.writeln('$_clean ${entry.key} ${entry.lengths.join(' ')}');
      }
    }

    await writer.flush();
    await writer.close();

    if (_journalFile.existsSync()) {
      if (_journalFileBackup.existsSync()) {
        _journalFileBackup.deleteSync();
      }

      _journalFile.renameSync(_journalFileBackup.path);
    }

    _journalFileTmp.renameSync(_journalFile.path);

    _journalWriter = _journalFile.openWrite(mode: FileMode.append);
  }

  Future<void> cleanup() async {
    // Closed.
    if (_journalWriter == null) {
      return;
    }

    _trimToSize();

    if (_journalRebuildRequired()) {
      await _rebuildJournal();
      _redundantOpCount = 0;
    }
  }

  @override
  Future<void> clear() async {
    _checkNotClosed();

    final entries = List.of(_lruEntries.values);

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

    var entry = _lruEntries[key];

    // Snapshot is stale.
    if (expectedSequenceNumber != CacheStore.anySequenceNumber &&
        (entry == null || entry.sequenceNumber != expectedSequenceNumber)) {
      return null;
    }

    if (entry == null) {
      entry = _Entry(fileSystem, directory, key, valueCount);
      _lruEntries[key] = entry;
    }
    // Another edit is in progress.
    else if (entry.editor != null) {
      return null;
    }

    final editor = _Editor(this, entry, valueCount);
    entry.editor = editor;

    _journalWriter.writeln('$_dirty $key');

    // Flush the journal before creating files to prevent file leaks.
    await _journalWriter.flush();

    return editor;
  }

  void _checkNotClosed() {
    if (_journalWriter == null) {
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

        if (!entry.getDirtyFile(i).existsSync()) {
          return editor.abort();
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

    _redundantOpCount++;

    entry.editor = null;

    if (entry.readable || success) {
      entry.readable = true;

      _journalWriter.writeln('$_clean ${entry.key} ${entry.lengths.join(' ')}');

      if (success) {
        entry.sequenceNumber = _nextSequenceNumber++;
      }
    } else {
      _lruEntries.remove(entry.key);
      _journalWriter.writeln('$_remove ${entry.key}');
    }

    await _journalWriter.flush();

    if (_size > maxSize || _journalRebuildRequired()) {
      await cleanup();
    }
  }

  @override
  Future<Snapshot> get(String key) async {
    _checkNotClosed();
    _validateKey(key);

    final entry = _lruEntries[key];

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

    _redundantOpCount++;

    _journalWriter.writeln('$_read $key');

    if (_journalRebuildRequired()) {
      await cleanup();
    }

    return _Snapshot(this, key, entry.sequenceNumber, streams, entry.lengths);
  }

  bool _journalRebuildRequired() {
    return _redundantOpCount >= 2000 && _redundantOpCount >= _lruEntries.length;
  }

  @override
  Future<bool> remove(String key) async {
    _checkNotClosed();
    _validateKey(key);

    final entry = _lruEntries[key];

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

    _redundantOpCount++;

    _journalWriter.writeln('$_remove $key');

    _lruEntries.remove(key);

    if (_journalRebuildRequired()) {
      await cleanup();
    }

    return true;
  }

  @override
  Future<int> size() async {
    return _lruEntries.values.fold<int>(0, (a, b) => a + b.length);
  }

  @override
  Future<void> close() async {
    if (_journalWriter == null) {
      return;
    }

    await _journalWriter.flush();
    await _journalWriter.close();

    _journalWriter = null;
  }

  @override
  bool get isClosed => _journalWriter == null;

  void _trimToSize([int forcedSize]) {
    final maxSize = forcedSize ?? this.maxSize;

    while (_size > maxSize) {
      final first = _lruEntries.isEmpty ? null : _lruEntries.values.first;
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

  _Entry(FileSystem fileSystem, String directory, this.key, this.valueCount)
      : lengths = List.filled(valueCount, 0),
        _cleanFiles = List.generate(valueCount,
            (i) => fileSystem.file(path.join(directory, '$key.$i'))),
        _dirtyFiles = List.generate(valueCount,
            (i) => fileSystem.file(path.join(directory, '$key.$i.tmp')));

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
  final LruCacheStore cache;

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

    return dirtyFile.openRead();
  }
}
