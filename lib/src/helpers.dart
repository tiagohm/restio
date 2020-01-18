import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:ip/ip.dart';
import 'package:restio/src/encodings.dart';
import 'package:restio/src/response.dart';

Encoding obtainEncodingByName(
  String name, [
  Encoding defaultValue = utf8,
]) {
  final encoding = Encoding.getByName(name);
  if (encoding == null) {
    name = name?.toLowerCase();
    if (name == 'utf-16') {
      return utf16;
    }

    if (name == 'utf-16le') {
      return utf16le;
    }

    if (name == 'utf-16be') {
      return utf16be;
    }

    if (name == 'utf-32') {
      return utf32;
    }

    return defaultValue;
  } else {
    return encoding;
  }
}

final _random = Random();
const _allowedChars = 'abcdefghijklmnopqrstuvwxyz0123456789';

String generateNonce(int length) {
  final nonce = StringBuffer('');

  for (var i = 0; i < length; i++) {
    nonce.write(_allowedChars[(_random.nextInt(_allowedChars.length))]);
  }

  return nonce.toString();
}

Future<List<int>> readAsBytes(Stream<List<int>> source) {
  final completer = Completer<List<int>>();

  final sink = ByteConversionSink.withCallback(completer.complete);

  source.listen(
    sink.add,
    onError: completer.completeError,
    onDone: sink.close,
    cancelOnError: true,
  );

  return completer.future;
}

bool isIp(String ip) {
  try {
    return IpAddress.parse(ip) != null;
  } catch (e) {
    return false;
  }
}

List<Cookie> obtainCookiesFromResponse(Response response) {
  final cookies = <Cookie>[];

  response.headers.forEach((name, value) {
    if (name == 'set-cookie') {
      try {
        final cookie = Cookie.fromSetCookieValue(value);
        if (cookie.name != null && cookie.name.isNotEmpty) {
          final domain = cookie.domain == null
              ? response.request.uri.host
              : cookie.domain.startsWith('.')
                  ? cookie.domain.substring(1)
                  : cookie.domain;
          final newCookie = Cookie(cookie.name, cookie.value)
            ..expires = cookie.expires
            ..maxAge = cookie.maxAge
            ..domain = domain
            ..path = cookie.path ?? response.request.uri.path
            ..secure = cookie.secure
            ..httpOnly = cookie.httpOnly;
          // Adiciona à lista de cookies a salvar.
          cookies.add(newCookie);
        }
      } catch (e) {
        // nada.
      }
    }
  });

  return cookies;
}

const formEncodeSet = " \"':;<=>@[]^`{}|/\\?#&!\$(),~";
const usernameEncodeSet = " \"':;<=>@[]^`{}|/\\?#";
const passwordEncodeSet = " \"':;<=>@[]^`{}|/\\?#";
const pathSegmentEncodeSet = ' \"<>^`{}|/\\?#';
const queryEncodeSet = " \"'<>#";
const fragmentEncodeSet = '';
const queryComponentEncodeSet = " !\"#\$&'(),/:;<=>?@[]\\^`{|}~";

const _hexDigits = [
  48,
  49,
  50,
  51,
  52,
  53,
  54,
  55,
  56,
  57,
  65,
  66,
  67,
  68,
  69,
  70
];

List<int> canonicalize(
  String input,
  String encodeSet, {
  bool plusIsSpace = false,
  bool asciiOnly = true,
  Encoding encoding,
}) {
  if (input == null) {
    return null;
  }

  if (input.isEmpty) {
    return const [];
  }

  encoding ??= utf8;

  final res = <int>[];

  for (var i = 0; i < input.length; i++) {
    final c = input[i];
    final codeUnit = input.codeUnitAt(i);

    if (c == '+' && plusIsSpace) {
      res..add(37)..add(50)..add(66); // %2B.
    } else if (codeUnit < 0x20 ||
        codeUnit == 0x7f ||
        codeUnit >= 0x80 && asciiOnly ||
        encodeSet.contains(c) ||
        c == '%') {
      final bytes = encoding.encode(c);

      for (final byte in bytes) {
        res
          ..add(37)
          ..add(_hexDigits[(byte >> 4) & 0xf])
          ..add(_hexDigits[byte & 0xf]);
      }
    } else {
      res.addAll(encoding.encode(c));
    }
  }

  return res;
}

String canonicalizeToString(
  String input,
  String encodeSet, {
  bool plusIsSpace = false,
  bool asciiOnly = true,
  Encoding encoding,
}) {
  if (input == null) {
    return null;
  }

  if (input.isEmpty) {
    return '';
  }

  encoding ??= utf8;

  return encoding.decode(
    canonicalize(
      input,
      encodeSet,
      plusIsSpace: plusIsSpace,
      asciiOnly: asciiOnly,
      encoding: encoding,
    ),
  );
}
