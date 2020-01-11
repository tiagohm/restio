import 'dart:io';

import 'package:restio/src/utils/string_pair_list.dart';

// ignore_for_file: avoid_returning_this

class Headers extends StringPairList {
  const Headers._(List<String> items) : super(items);

  HeadersBuilder toBuilder() {
    return HeadersBuilder._(this);
  }

  @override
  bool get isCaseSensitive => false;

  static Headers of(Map<String, dynamic> items) {
    final headers = HeadersBuilder();
    items.forEach(headers.add);
    return headers.build();
  }

  List<String> vary() {
    final values = all(HttpHeaders.varyHeader);
    final res = <String>[];

    for (final value in values) {
      if (value != null) {
        final fields = value.split(',');

        for (final field in fields) {
          res.add(field.trim().toLowerCase());
        }
      }
    }

    return res;
  }

  bool get hasVaryAll => vary().contains('*');

  @override
  String toString() {
    final sb = StringBuffer();

    sb.write('Headers {');

    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) {
        sb.write(', ');
      }

      sb..write(items[i])..write(':')..write(items[i + 1]);
    }

    sb.write('}');

    return sb.toString();
  }
}

class HeadersBuilder extends StringPairListBuilder<Headers> {
  HeadersBuilder() : super();

  HeadersBuilder._(Headers headers) {
    headers.copyToBuilder(this);
  }

  @override
  bool get isCaseSensitive => false;

  HeadersBuilder addLine(String line) {
    final index = line.indexOf(':', 1);

    if (index != -1) {
      return add(
        line.substring(0, index).trim(),
        line.substring(index + 1).trim(),
      );
    } else if (line.startsWith(':')) {
      // Work around empty header names and header names that start with a
      // colon (created by old broken SPDY versions of the response cache).
      return add('', line.substring(1).trim()); // Empty header name.
    } else {
      return add('', line); // No header name.
    }
  }

  @override
  Headers build() {
    return Headers._(items);
  }
}
