import 'dart:convert';
import 'dart:io' as io;

import 'package:restio/restio.dart';
import 'package:test/test.dart';
import 'package:path/path.dart' as path;

final cacheDir = io.Directory('./.cache');
final journalFile =
    io.File(path.join(cacheDir.path, LruCacheStore.journalFile));
final journalFileBackup =
    io.File(path.join(cacheDir.path, LruCacheStore.journalFileBackup));
final journalFileTmp =
    io.File(path.join(cacheDir.path, LruCacheStore.journalFileTmp));

const a = [65];
const b = [66];
const cd = [67, 68];
const c = [67];
const d = [68];

Future<CacheStore> openCache({
  int maxSize = 1000000000,
}) {
  return LruCacheStore.local(
    './.cache',
    maxSize: maxSize,
  );
}

void main() {
  CacheStore cache;

  setUp(() async {
    if (!cacheDir.existsSync()) {
      cacheDir.createSync();
    } else {
      cacheDir.listSync(recursive: true).forEach((i) => i.deleteSync());
    }

    cache = await openCache();
  });

  test('Validate Key', () {
    expect(() => cache.edit('has_space '), throwsA(isA<ArgumentError>()));
    expect(() => cache.edit('has_CR\r'), throwsA(isA<ArgumentError>()));
    expect(() => cache.edit('has_LF\n'), throwsA(isA<ArgumentError>()));
    expect(() => cache.edit('has_invalid/'), throwsA(isA<ArgumentError>()));
    expect(() => cache.edit(List.generate(13, (i) => '_too_long_').join()),
        throwsA(isA<ArgumentError>()));
    expect(() => cache.edit(List.generate(12, (i) => 'exactly120').join()),
        isNot(isA<ArgumentError>()));
  });

  test('Write And Read', () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    await set(editor, 1, b);

    expect(editor.newSource(0), isNull);
    expect(editor.newSource(1), isNull);

    await editor.commit();

    final snapshot = await cache.get('k1');

    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(b));
  });

  test('Read And Write Entry Across Cache Open And Close', () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.commit();
    await cache.close();

    cache = await openCache();

    final snapshot = await cache.get('k1');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(b));
  });

  test('Read ead And Write Entry Without Proper Close', () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.commit();

    final cache2 = await openCache();

    final snapshot = await cache2.get('k1');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(b));
    await cache2.close();
  });

  test('Journal With Edit And Publish', () async {
    final editor = await cache.edit('k1');

    await expectJournalEquals(['DIRTY k1']);

    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.commit();
    await cache.close();

    await expectJournalEquals(['DIRTY k1', 'CLEAN k1 1 1']);
  });

  test('Reverted New File Is Remov eIn Journal', () async {
    final editor = await cache.edit('k1');

    await expectJournalEquals(['DIRTY k1']);

    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.abort();
    await cache.close();

    await expectJournalEquals(['DIRTY k1', 'REMOVE k1']);
  });

  test('Unterminated Edit Is Reverted On Close', () async {
    await cache.edit('k1');
    await cache.close();
    await expectJournalEquals(['DIRTY k1', 'REMOVE k1']);
  });

  test('Journal Does Not Include Read Of Yet Unpublished Value', () async {
    final editor1 = await cache.edit('k1');
    await set(editor1, 0, a);
    await set(editor1, 1, b);
    await editor1.commit();

    final editor2 = await cache.edit('k2');
    await set(editor2, 0, b);
    await set(editor2, 1, cd);
    await editor2.commit();

    await cache.get('k1');

    await cache.close();

    await expectJournalEquals(
        ['DIRTY k1', 'CLEAN k1 1 1', 'DIRTY k2', 'CLEAN k2 1 2', 'READ k1']);
  });

  test('Journal With Edit And Publish And Read', () async {
    final editor = await cache.edit('k1');

    expect(await cache.get('k1'), isNull);

    await set(editor, 0, a);
    await set(editor, 1, cd);
    await editor.commit();
    await cache.close();

    await expectJournalEquals(['DIRTY k1', 'CLEAN k1 1 2']);
  });

  test('Can Not Operate On Edit After Publish', () async {
    final editor = await cache.edit('k1');

    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.commit();

    expect(() => editor.newSource(0), throwsA(isA<StateError>()));
    expect(() => editor.newSource(1), throwsA(isA<StateError>()));
  });

  test('Can Not Operate On Edit After Revert', () async {
    final editor = await cache.edit('k1');

    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.abort();

    expect(() => editor.newSource(0), throwsA(isA<StateError>()));
    expect(() => editor.newSource(1), throwsA(isA<StateError>()));
  });

  test('Read And Write Overlaps Maintain Consistency', () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.commit();

    final snapshot1 = await cache.get('k1');
    expect(snapshot1.source(0), emits(a));

    final updater = await cache.edit('k1');
    await set(updater, 0, b);
    await set(updater, 1, cd);
    await updater.commit();

    final snapshot2 = await cache.get('k1');
    expect(snapshot2.source(0), emits(b));
    expect(snapshot2.source(1), emits(cd));
    await snapshot2.close();

    expect(snapshot1.source(1), emits(b));
  });

  test('Open With Dirty Key Deletes All Files For That Key', () async {
    await cache.close();

    await writeFile(getCleanFile('k1', 0), a);
    await writeFile(getCleanFile('k1', 1), a);
    await writeFile(getDirtyFile('k1', 0), a);
    await writeFile(getDirtyFile('k1', 1), a);

    await createJournal(['CLEAN k1 1 1', 'DIRTY k1']);

    cache = await openCache();

    expect(getCleanFile('k1', 0).existsSync(), false);
    expect(getCleanFile('k1', 1).existsSync(), false);
    expect(getDirtyFile('k1', 0).existsSync(), false);
    expect(getDirtyFile('k1', 1).existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Open With Invalid Version Clears Directory', () async {
    await cache.close();

    final garbageFile = io.File(path.join(cacheDir.path, 'lixo'));
    await writeFile(garbageFile, a);

    await createJournal([], version: '0');

    cache = await openCache();

    expect(garbageFile.existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Open With Invalid App Version Clears Directory', () async {
    await cache.close();

    final garbageFile = io.File(path.join(cacheDir.path, 'lixo'));
    await writeFile(garbageFile, a);

    await createJournal([], appVersion: 101);

    cache = await openCache();

    expect(garbageFile.existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Open With Invalid Value Count Clears Directory', () async {
    await cache.close();

    final garbageFile = io.File(path.join(cacheDir.path, 'lixo'));
    await writeFile(garbageFile, a);

    await createJournal([], valueCount: 1);

    cache = await openCache();

    expect(garbageFile.existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Open With Invalid Journal Line Clears Directory', () async {
    await cache.close();

    final garbageFile = io.File(path.join(cacheDir.path, 'lixo'));
    await writeFile(garbageFile, a);

    await createJournal(['CLEAN k1 1 1', 'BOGUS']);

    cache = await openCache();

    expect(garbageFile.existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Open With Invalid File Size Clears Directory', () async {
    await cache.close();

    final garbageFile = io.File(path.join(cacheDir.path, 'lixo'));
    await writeFile(garbageFile, a);

    await createJournal(['CLEAN k1 0000x001 1']);

    cache = await openCache();

    expect(garbageFile.existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Open With Truncated Line Discards That Line', () async {
    await cache.close();

    await writeFile(getCleanFile('k1', 0), a);
    await writeFile(getCleanFile('k1', 1), a);

    await createJournal(['CLEAN k1 1 1'], noTrailingNewLine: true);

    cache = await openCache();

    expect(await cache.get('k1'), isNull);

    final editor = await cache.edit('k1');
    await set(editor, 0, b);
    await set(editor, 1, b);
    await editor.commit();

    await cache.close();

    cache = await openCache();

    final snapshot = await cache.get('k1');
    expect(snapshot.source(0), emits(b));
    expect(snapshot.source(1), emits(b));
  });

  test('Open With Too Many File Sizes Clears Directory', () async {
    await cache.close();

    final garbageFile = io.File(path.join(cacheDir.path, 'lixo'));
    await writeFile(garbageFile, a);

    await createJournal(['CLEAN k1 1 1 1']);

    cache = await openCache();

    expect(garbageFile.existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Create New Entry With Too Few Values Fails', () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    expect(editor.commit, throwsA(isA<StateError>()));

    expect(getCleanFile('k1', 0).existsSync(), false);
    expect(getCleanFile('k1', 1).existsSync(), false);
    expect(getDirtyFile('k1', 0).existsSync(), false);
    expect(getDirtyFile('k1', 1).existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Revert With Too Few Values', () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    await editor.abort();

    expect(getCleanFile('k1', 0).existsSync(), false);
    expect(getCleanFile('k1', 1).existsSync(), false);
    expect(getDirtyFile('k1', 0).existsSync(), false);
    expect(getDirtyFile('k1', 1).existsSync(), false);
    expect(await cache.get('k1'), isNull);
  });

  test('Update Existing Entry With Too Few Values Reuses Previous Values',
      () async {
    final editor = await cache.edit('k1');
    await set(editor, 0, a);
    await set(editor, 1, b);
    await editor.commit();

    final updater = await cache.edit('k1');
    await set(updater, 0, c);
    await updater.commit();

    final snapshot = await cache.get('k1');
    expect(snapshot.source(0), emits(c));
    expect(snapshot.source(1), emits(b));
  });

  test('Grow Max Size', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    var editor = await cache.edit('a');
    await set(editor, 0, 'a'.codeUnits); // 1
    await set(editor, 1, 'aaa'.codeUnits); // 3
    await editor.commit();

    editor = await cache.edit('b');
    await set(editor, 0, 'bb'.codeUnits); // 2
    await set(editor, 1, 'bbbb'.codeUnits); // 4
    await editor.commit();

    await (cache as LruCacheStore).increaseMaxSize(12);

    editor = await cache.edit('c');
    await set(editor, 0, 'c'.codeUnits); // 1
    await set(editor, 1, 'c'.codeUnits); // 1
    await editor.commit();

    expect(await cache.size(), 12);
  });

  test('Shrink Max Size Evicts', () async {
    await cache.close();

    cache = await openCache(maxSize: 20);

    var editor = await cache.edit('a');
    await set(editor, 0, 'a'.codeUnits); // 1
    await set(editor, 1, 'aaa'.codeUnits); // 3
    await editor.commit();

    editor = await cache.edit('b');
    await set(editor, 0, 'bb'.codeUnits); // 2
    await set(editor, 1, 'bbbb'.codeUnits); // 4
    await editor.commit();

    editor = await cache.edit('c');
    await set(editor, 0, 'c'.codeUnits); // 1
    await set(editor, 1, 'c'.codeUnits); // 1
    await editor.commit();

    expect(await cache.size(), 12);

    await (cache as LruCacheStore).increaseMaxSize(10);

    expect(await cache.size(), lessThanOrEqualTo(10));
  });

  test('Evict On Insert', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    var editor = await cache.edit('a');
    await set(editor, 0, 'a'.codeUnits); // 1
    await set(editor, 1, 'aaa'.codeUnits); // 3
    await editor.commit();

    editor = await cache.edit('b');
    await set(editor, 0, 'bb'.codeUnits); // 2
    await set(editor, 1, 'bbbb'.codeUnits); // 4
    await editor.commit();

    expect(await cache.size(), 10);

    editor = await cache.edit('c');
    await set(editor, 0, 'c'.codeUnits); // 1
    await set(editor, 1, 'c'.codeUnits); // 1
    await editor.commit();

    expect(await cache.get('a'), isNull);
    expect(await cache.size(), 8);

    editor = await cache.edit('d');
    await set(editor, 0, 'd'.codeUnits); // 1
    await set(editor, 1, 'd'.codeUnits); // 1
    await editor.commit();

    expect(await cache.size(), 10);

    editor = await cache.edit('e');
    await set(editor, 0, 'eeee'.codeUnits); // 4
    await set(editor, 1, 'eeee'.codeUnits); // 4
    await editor.commit();

    expect(await cache.get('a'), isNull);
    expect(await cache.get('b'), isNull);
    expect(await cache.get('c'), isNull);
    expect(await cache.size(), 10);
  });

  test('Evict On Update', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    var editor = await cache.edit('a');
    await set(editor, 0, 'a'.codeUnits); // 1
    await set(editor, 1, 'aa'.codeUnits); // 2
    await editor.commit();

    editor = await cache.edit('b');
    await set(editor, 0, 'b'.codeUnits); // 1
    await set(editor, 1, 'bb'.codeUnits); // 2
    await editor.commit();

    editor = await cache.edit('c');
    await set(editor, 0, 'c'.codeUnits); // 1
    await set(editor, 1, 'cc'.codeUnits); // 2
    await editor.commit();

    expect(await cache.size(), 9);

    editor = await cache.edit('b');
    await set(editor, 0, 'b'.codeUnits); // 1
    await set(editor, 1, 'bbbb'.codeUnits); // 4
    await editor.commit();

    expect(await cache.size(), 8);
    expect(await cache.get('a'), isNull);
  });

  test('Cache Single Entry Of Size Greater Than Max Size', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    final editor = await cache.edit('a');
    await set(editor, 0, 'aaaaa'.codeUnits); // 5
    await set(editor, 1, 'aaaaaa'.codeUnits); // 6
    await editor.commit();

    expect(await cache.size(), isZero);
    expect(await cache.get('a'), isNull);
  });

  test('Cache Single Value Of Size Greater Than Max Size', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    final editor = await cache.edit('a');
    await set(editor, 0, 'aaaaaaaaaaa'.codeUnits); // 11
    await set(editor, 1, 'a'.codeUnits); // 1
    await editor.commit();

    expect(await cache.size(), isZero);
    expect(await cache.get('a'), isNull);
  });

  test('Rebuild Journal On Repeated Reads', () async {
    await cache.close();

    cache = await openCache();

    var editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    editor = await cache.edit('b');
    await set(editor, 0, b);
    await set(editor, 1, b);
    await editor.commit();

    var lastJournalLength = 0;

    while (true) {
      final journalLength = journalFile.lengthSync();

      var snapshot = await cache.get('a');
      expect(snapshot.source(0), emits(a));
      expect(snapshot.source(1), emits(a));
      await snapshot.close();

      snapshot = await cache.get('b');
      expect(snapshot.source(0), emits(b));
      expect(snapshot.source(1), emits(b));
      await snapshot.close();

      if (journalLength < lastJournalLength) {
        print(
            'Journal compacted from $lastJournalLength bytes to $journalLength bytes');
        break;
      }

      lastJournalLength = journalLength;
    }
  });

  test('Rebuild Journal On Repeated Edits', () async {
    await cache.close();

    cache = await openCache();

    var lastJournalLength = 0;

    while (true) {
      final journalLength = journalFile.lengthSync();

      var editor = await cache.edit('a');
      await set(editor, 0, a);
      await set(editor, 1, a);
      await editor.commit();

      editor = await cache.edit('b');
      await set(editor, 0, b);
      await set(editor, 1, b);
      await editor.commit();

      if (journalLength < lastJournalLength) {
        print(
            'Journal compacted from $lastJournalLength bytes to $journalLength bytes');
        break;
      }

      lastJournalLength = journalLength;
    }

    // Sanity check that a rebuilt journal behaves normally.
    var snapshot = await cache.get('a');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(a));
    await snapshot.close();

    snapshot = await cache.get('b');
    expect(snapshot.source(0), emits(b));
    expect(snapshot.source(1), emits(b));
    await snapshot.close();
  });

  test('Rebuild Journal On Repeated Reads With Open And Close', () async {
    await cache.close();

    cache = await openCache();

    var editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    editor = await cache.edit('b');
    await set(editor, 0, b);
    await set(editor, 1, b);
    await editor.commit();

    var lastJournalLength = 0;

    while (true) {
      final journalLength = journalFile.lengthSync();

      var snapshot = await cache.get('a');
      expect(snapshot.source(0), emits(a));
      expect(snapshot.source(1), emits(a));
      await snapshot.close();

      snapshot = await cache.get('b');
      expect(snapshot.source(0), emits(b));
      expect(snapshot.source(1), emits(b));
      await snapshot.close();

      await cache.close();

      cache = await openCache();

      if (journalLength < lastJournalLength) {
        print(
            'Journal compacted from $lastJournalLength bytes to $journalLength bytes');
        break;
      }

      lastJournalLength = journalLength;
    }
  });

  test('Rebuild Journal On Repeated Edits With Open And Close', () async {
    await cache.close();

    cache = await openCache();

    var lastJournalLength = 0;

    while (true) {
      final journalLength = journalFile.lengthSync();

      var editor = await cache.edit('a');
      await set(editor, 0, a);
      await set(editor, 1, a);
      await editor.commit();

      editor = await cache.edit('b');
      await set(editor, 0, b);
      await set(editor, 1, b);
      await editor.commit();

      await cache.close();

      cache = await openCache();

      if (journalLength < lastJournalLength) {
        print(
            'Journal compacted from $lastJournalLength bytes to $journalLength bytes');
        break;
      }

      lastJournalLength = journalLength;
    }
  });

  test('Restore Backup File', () async {
    final editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    journalFile.renameSync(journalFileBackup.path);
    expect(journalFileBackup.existsSync(), true);
    expect(journalFile.existsSync(), false);

    cache = await openCache();

    final snapshot = await cache.get('a');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(a));
    await snapshot.close();

    expect(journalFileBackup.existsSync(), false);
    expect(journalFile.existsSync(), true);
  });

  test('Journal File Is Preferred Over Backup File', () async {
    var editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    journalFile.copySync(journalFileBackup.path);

    editor = await cache.edit('b');
    await set(editor, 0, b);
    await set(editor, 1, b);
    await editor.commit();

    await cache.close();

    expect(journalFileBackup.existsSync(), true);
    expect(journalFile.existsSync(), true);

    cache = await openCache();

    var snapshot = await cache.get('a');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(a));
    await snapshot.close();

    snapshot = await cache.get('b');
    expect(snapshot.source(0), emits(b));
    expect(snapshot.source(1), emits(b));
    await snapshot.close();
  });

  test('File Deleted Externally', () async {
    final editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    getCleanFile('a', 1).deleteSync();

    expect(await cache.get('a'), isNull);
  });

  test('Edit Same Version', () async {
    var editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    var snapshot = await cache.get('a');
    editor = await snapshot.edit();
    await set(editor, 1, b);
    await editor.commit();

    snapshot = await cache.get('a');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(b));
    await snapshot.close();
  });

  test('Edit Snapshot After Change Aborted', () async {
    var editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    var snapshot = await cache.get('a');
    editor = await snapshot.edit();
    await set(editor, 0, b);
    await editor.abort();

    editor = await snapshot.edit();
    await set(editor, 1, c);
    await editor.commit();

    snapshot = await cache.get('a');
    expect(snapshot.source(0), emits(a));
    expect(snapshot.source(1), emits(c));
    await snapshot.close();
  });

  test('Edit Snapshot After Change Commited', () async {
    var editor = await cache.edit('a');
    await set(editor, 0, a);
    await set(editor, 1, a);
    await editor.commit();

    final snapshot = await cache.get('a');
    editor = await snapshot.edit();
    await set(editor, 0, b);
    await editor.commit();

    expect(await snapshot.edit(), isNull);
  });

  test('Edit Since Evicted', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    var editor = await cache.edit('a');
    await set(editor, 0, 'aa'.codeUnits);
    await set(editor, 1, 'aaa'.codeUnits);
    await editor.commit();

    final snapshot = await cache.get('a');

    editor = await cache.edit('b');
    await set(editor, 0, 'bb'.codeUnits);
    await set(editor, 1, 'bbb'.codeUnits);
    await editor.commit();

    editor = await cache.edit('c');
    await set(editor, 0, 'cc'.codeUnits);
    await set(editor, 1, 'ccc'.codeUnits);
    await editor.commit(); // will evict 'a'

    expect(await snapshot.edit(), isNull);
  });

  test('Edit Since Evicted And Recreated', () async {
    await cache.close();

    cache = await openCache(maxSize: 10);

    var editor = await cache.edit('a');
    await set(editor, 0, 'aa'.codeUnits);
    await set(editor, 1, 'aaa'.codeUnits);
    await editor.commit();

    final snapshot = await cache.get('a');

    editor = await cache.edit('b');
    await set(editor, 0, 'bb'.codeUnits);
    await set(editor, 1, 'bbb'.codeUnits);
    await editor.commit();

    editor = await cache.edit('c');
    await set(editor, 0, 'cc'.codeUnits);
    await set(editor, 1, 'ccc'.codeUnits);
    await editor.commit(); // will evict 'a'

    editor = await cache.edit('a');
    await set(editor, 0, 'aa'.codeUnits);
    await set(editor, 1, 'aaa'.codeUnits);
    await editor.commit(); // will evict 'b'

    expect(await snapshot.edit(), isNull);
  });
}

Future<void> writeFile(
  io.File file,
  List<int> data,
) async {
  final writer = file.openWrite();
  writer.add(data);
  await writer.flush();
  await writer.close();
}

Future<void> set(
  Editor editor,
  int index,
  List<int> data,
) async {
  await (editor.newSink(index)..add(data)).close();
}

Future<void> expectJournalEquals(List<String> lines) async {
  final journalFile = io.File(path.join(cacheDir.path, 'journal'));

  final lines = await journalFile
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .toList();

  expect(lines.length, greaterThanOrEqualTo(5));
  expect(lines[0], LruCacheStore.magic);
  expect(lines[1], '1');
  expect(lines[2], '1');
  expect(lines[3], '2');
  expect(lines[4], isEmpty);
}

Future<void> createJournal(
  List<String> lines, {
  String magic = LruCacheStore.magic,
  String version = '1',
  int appVersion = 1,
  int valueCount = 2,
  bool noTrailingNewLine = false,
}) async {
  final journalFile = io.File(path.join(cacheDir.path, 'journal'));

  final writer = journalFile.openWrite();
  writer.writeln(magic);
  writer.writeln(version);
  writer.writeln(appVersion.toString());
  writer.writeln(valueCount.toString());
  writer.writeln();

  if (noTrailingNewLine) {
    lines.forEach(writer.write);
  } else {
    lines.forEach(writer.writeln);
  }

  await writer.flush();
  await writer.close();
}

io.File getCleanFile(
  String key,
  int index,
) {
  return io.File(path.join(cacheDir.path, '$key.$index'));
}

io.File getDirtyFile(
  String key,
  int index,
) {
  return io.File(path.join(cacheDir.path, '$key.$index.tmp'));
}
