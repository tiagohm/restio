import 'package:restio/restio.dart';
import 'package:test/test.dart';

void main() {
  test('NameAt And ValueAt', () {
    final builder = HeadersBuilder();
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
    final builder = HeadersBuilder();
    builder.add('foo', 'bar');
    builder.add('foo', 'baz');
    builder.add('bar', 'foo');

    var headers = builder.build();

    expect(headers.length, 3);

    builder.removeAll('foo');

    headers = builder.build();

    expect(headers.length, 1);
  });

  test('Remove At', () {
    final builder = HeadersBuilder()
      ..add('foo', 'bar')
      ..add('foo', 'baz')
      ..add('bar', 'foo')
      ..removeAt(2);

    final headers = builder.build();

    expect(headers.length, 2);
    expect(headers.has('bar'), false);
  });

  test('Remove First', () {
    final builder = HeadersBuilder()
      ..add('foo', 'bar')
      ..add('foo', 'baz')
      ..add('bar', 'foo')
      ..removeFirst('foo');

    final headers = builder.build();

    expect(headers.length, 2);
    expect(headers.value('foo'), 'baz');
  });

  test('Remove Last', () {
    final builder = HeadersBuilder()
      ..add('foo', 'bar')
      ..add('foo', 'baz')
      ..add('bar', 'foo')
      ..removeLast('foo');

    final headers = builder.build();

    expect(headers.length, 2);
    expect(headers.value('foo'), 'bar');
  });

  test('Headers is Not Case Sensitive', () {
    final builder = HeadersBuilder();
    builder.add('STRING', 'foo');
    builder.add('bool', true);
    builder.add('iNt', 5);

    final headers = builder.build();

    expect(headers.value('string'), 'foo');
    expect(headers.value('BOOL'), 'true');
    expect(headers.value('InT'), '5');
  });

  test('Headers Preservers Case', () {
    final builder = HeadersBuilder();
    builder.add('STRING', 'foo');
    final headers = builder.build();

    expect(headers.nameAt(0), 'STRING');
  });
}
