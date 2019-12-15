import 'dart:convert';

import 'package:utf/utf.dart';

const utf16 = Utf16Codec();

class Utf16Codec extends Encoding {
  const Utf16Codec();

  @override
  Converter<List<int>, String> get decoder => const Utf16Decoder();

  @override
  Converter<String, List<int>> get encoder => const Utf16Encoder();

  @override
  String get name => 'utf-16';
}

class Utf16Encoder extends Converter<String, List<int>> {
  const Utf16Encoder();

  @override
  List<int> convert(String input) {
    return encodeUtf16(input);
  }
}

class Utf16Decoder extends Converter<List<int>, String> {
  const Utf16Decoder();

  @override
  String convert(List<int> input) {
    return decodeUtf16(input);
  }
}

const utf16be = Utf16BeCodec();

class Utf16BeCodec extends Encoding {
  const Utf16BeCodec();

  @override
  Converter<List<int>, String> get decoder => const Utf16Decoder();

  @override
  Converter<String, List<int>> get encoder => const Utf16Encoder();

  @override
  String get name => 'utf-16be';
}

class Utf16BeEncoder extends Converter<String, List<int>> {
  const Utf16BeEncoder();

  @override
  List<int> convert(String input) {
    return encodeUtf16be(input);
  }
}

class Utf16BeDecoder extends Converter<List<int>, String> {
  const Utf16BeDecoder();

  @override
  String convert(List<int> input) {
    return decodeUtf16be(input);
  }
}

const utf16le = Utf16LeCodec();

class Utf16LeCodec extends Encoding {
  const Utf16LeCodec();

  @override
  Converter<List<int>, String> get decoder => const Utf16Decoder();

  @override
  Converter<String, List<int>> get encoder => const Utf16Encoder();

  @override
  String get name => 'utf-16le';
}

class Utf16LeEncoder extends Converter<String, List<int>> {
  const Utf16LeEncoder();

  @override
  List<int> convert(String input) {
    return encodeUtf16le(input);
  }
}

class Utf16LeDecoder extends Converter<List<int>, String> {
  const Utf16LeDecoder();

  @override
  String convert(List<int> input) {
    return decodeUtf16le(input);
  }
}

const utf32 = Utf32Codec();

class Utf32Codec extends Encoding {
  const Utf32Codec();

  @override
  Converter<List<int>, String> get decoder => const Utf32Decoder();

  @override
  Converter<String, List<int>> get encoder => const Utf32Encoder();

  @override
  String get name => 'utf-32';
}

class Utf32Encoder extends Converter<String, List<int>> {
  const Utf32Encoder();

  @override
  List<int> convert(String input) {
    return encodeUtf32(input);
  }
}

class Utf32Decoder extends Converter<List<int>, String> {
  const Utf32Decoder();

  @override
  String convert(List<int> input) {
    return decodeUtf32(input);
  }
}
