import 'dart:convert';
import 'dart:io';

import 'package:restio/restio.dart';
import 'package:test/test.dart';

void main() {
  test('Parse', () {
    final mediaType = MediaType.parse('text/plain;boundary=foo; charset=utf-8');
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'text');
    expect(mediaType.subType, 'plain');
    expect(mediaType.charset, 'utf-8');
    expect(mediaType.boundary, 'foo');
    expect(mediaType.value, 'text/plain; boundary=foo; charset=utf-8');
  });

  test('Multipart/Form-Data is UTF-8', () {
    const mediaType = MediaType.multipartFormData;
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'multipart');
    expect(mediaType.subType, 'form-data');
    expect(mediaType.charset, null);
    expect(mediaType.encoding, utf8);
  });

  test('From File', () {
    var mediaType = MediaType.fromFile('./file.txt', charset: 'utf-8');
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'text');
    expect(mediaType.subType, 'plain');
    expect(mediaType.charset, 'utf-8');
    expect(mediaType.encoding, utf8);

    mediaType = MediaType.fromFile('./file.abc');
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'application');
    expect(mediaType.subType, 'octet-stream');
    expect(mediaType.charset, isNull);
    expect(mediaType.encoding, latin1);
  });

  test('From ContentType', () {
    var mediaType = MediaType.fromContentType(ContentType.json);
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'application');
    expect(mediaType.subType, 'json');
    expect(mediaType.charset, 'utf-8');
    expect(mediaType.encoding, utf8);

    mediaType = MediaType.fromContentType(ContentType.binary);
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'application');
    expect(mediaType.subType, 'octet-stream');
    expect(mediaType.charset, isNull);
    expect(mediaType.encoding, latin1);
  });

  test('Copy With', () {
    var mediaType =
        const MediaType(type: 'a', subType: 'b', parameters: {'c': 'd'});
    expect(mediaType.name, 'Content-Type');
    expect(mediaType.type, 'a');
    expect(mediaType.subType, 'b');
    expect(mediaType.charset, null);
    expect(mediaType.encoding, latin1);

    mediaType = mediaType.copyWith(type: 'e');
    expect(mediaType.type, 'e');

    mediaType = mediaType.copyWith(subType: 'e');
    expect(mediaType.subType, 'e');

    mediaType = mediaType.copyWith(charset: 'e');
    expect(mediaType.charset, 'e');

    mediaType = mediaType.copyWith(boundary: 'e');
    expect(mediaType.boundary, 'e');

    mediaType = mediaType.copyWith(parameters: const {'e': 'f'});
    expect(mediaType.charset, isNull);
    expect(mediaType.boundary, isNull);
    expect(mediaType.parameters.length, 1);
    expect(mediaType.parameters['e'], 'f');

    mediaType = mediaType.copyWith(charset: 'f', parameters: const {'g': 'h'});
    expect(mediaType.charset, 'f');
    expect(mediaType.parameters.length, 2);
    expect(mediaType.parameters['g'], 'h');
  });
}
