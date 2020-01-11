import 'package:restio/restio.dart';
import 'package:test/test.dart';

void main() {
  test('NameAt And ValueAt', () {
    final builder = QueriesBuilder();
    builder.add('string', 'foo');
    builder.add('string', 'bar');
    builder.add('int', 5);
    builder.add('float', 1.5);
    builder.add('bool', true);

    final headers = builder.build();

    expect(headers.nameAt(0), 'string');
    expect(headers.nameAt(1), 'string');
    expect(headers.nameAt(2), 'int');
    expect(headers.nameAt(3), 'float');
    expect(headers.nameAt(4), 'bool');
    expect(headers.valueAt(0), 'foo');
    expect(headers.valueAt(1), 'bar');
    expect(headers.valueAt(2), '5');
    expect(headers.valueAt(3), '1.5');
    expect(headers.valueAt(4), 'true');
  });

  test('Remove', () {
    final builder = QueriesBuilder();
    builder.add('foo', 'bar');
    builder.add('foo', 'baz');
    builder.add('bar', 'foo');

    var headers = builder.build();

    expect(headers.length, 3);

    builder.remove('foo');

    headers = builder.build();

    expect(headers.length, 1);
  });

  test('Remove At', () {
    final builder = QueriesBuilder()
      ..add('foo', 'bar')
      ..add('foo', 'baz')
      ..add('bar', 'foo')
      ..removeAt(2);

    final headers = builder.build();

    expect(headers.length, 2);
    expect(headers.has('bar'), false);
  });

  test('Remove First', () {
    final builder = QueriesBuilder()
      ..add('foo', 'bar')
      ..add('foo', 'baz')
      ..add('bar', 'foo')
      ..removeFirst('foo');

    final headers = builder.build();

    expect(headers.length, 2);
    expect(headers.value('foo'), 'baz');
  });

  test('Remove Last', () {
    final builder = QueriesBuilder()
      ..add('foo', 'bar')
      ..add('foo', 'baz')
      ..add('bar', 'foo')
      ..removeLast('foo');

    final headers = builder.build();

    expect(headers.length, 2);
    expect(headers.value('foo'), 'bar');
  });

  test('Queries is Case Sensitive', () {
    final builder = QueriesBuilder();
    builder.add('STRING', 'foo');
    builder.add('bool', true);
    builder.add('iNt', 5);

    final headers = builder.build();

    expect(headers.first('string'), isNull);
    expect(headers.first('BOOL'), isNull);
    expect(headers.first('InT'), isNull);
    expect(headers.first('STRING'), 'foo');
    expect(headers.first('bool'), 'true');
    expect(headers.first('iNt'), '5');
  });
}
