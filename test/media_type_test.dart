import 'package:restio/src/media_type.dart';
import 'package:test/test.dart';

void main() {
  test('Parse', () {
    final mediaType = MediaType.parse('text/plain;boundary=foo; charset=utf-8');
    expect(mediaType.type, 'text');
    expect(mediaType.subType, 'plain');
    expect(mediaType.charset, 'utf-8');
    expect(mediaType.parameters['boundary'], 'foo');
    expect(mediaType.toString(), 'text/plain; boundary=foo; charset=utf-8');
  });
}
