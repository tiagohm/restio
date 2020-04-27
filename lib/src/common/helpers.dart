import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brotli/brotli.dart';
import 'package:ip/ip.dart';

Future<List<int>> readStream(Stream<List<int>> source) {
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

const formEncodeSet = " \"':;<=>@[]^`{}|/\\?#&!\$(),~";
const usernameEncodeSet = " \"':;<=>@[]^`{}|/\\?#";
const passwordEncodeSet = " \"':;<=>@[]^`{}|/\\?#";
const pathSegmentEncodeSet = ' \"<>^`{}|/\\?#';
const queryEncodeSet = " \"'<>#";
const fragmentEncodeSet = '';
const queryComponentEncodeSet = " !\"#\$&'(),/:;<=>?@[]\\^`{|}~";

const _hexDigits = [
  48, 49, 50, 51, 52, 53, 54, 55, //
  56, 57, 65, 66, 67, 68, 69, 70, //
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

Converter<List<int>, List<int>> decoderByContentEncoding(
  String contentEncoding,
) {
  switch (contentEncoding) {
    case 'gzip':
      return gzip.decoder;
    case 'deflate':
      return zlib.decoder;
      break;
    case 'br':
    case 'brotli':
      return brotli.decoder;
      break;
    default:
      return null;
  }
}
