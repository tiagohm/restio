import 'package:restio/restio.dart';
import 'package:test/test.dart';

const a = [65];
const b = [66];
const cd = [67, 68];
const c = [67];
const d = [68];

Future<CacheStore> openCache() async {
  return MemoryCacheStore();
}

void main() {
  CacheStore cache;

  setUp(() async {
    cache = await openCache();
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
}

Future<void> set(
  Editor editor,
  int index,
  List<int> data,
) async {
  await (editor.newSink(index)..add(data)).close();
}
