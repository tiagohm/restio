import 'dart:convert';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

void main() {
  test('Parse', () {
    final mediaType = MediaType.parse('text/plain;boundary=foo; charset=utf-8');
    expect(mediaType.type, 'text');
    expect(mediaType.subType, 'plain');
    expect(mediaType.charset, 'utf-8');
    expect(mediaType.boundary, 'foo');
    expect(mediaType.toHeaderString(), 'text/plain; boundary=foo; charset=utf-8');
  });

  test('Multipart/Form-Data is UTF-8', () {
    const mediaType = MediaType.multipartFormData;
    expect(mediaType.type, 'multipart');
    expect(mediaType.subType, 'form-data');
    expect(mediaType.charset, null);
    expect(mediaType.encoding, utf8);
  });
}
