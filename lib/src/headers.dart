import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/utils/string_pair_list.dart';

// ignore_for_file: avoid_returning_this

class Headers extends StringPairList {
  @protected
  @override
  final List<String> items;

  const Headers._(this.items);

  static const empty = Headers._([]);

  HeadersBuilder toBuilder() {
    return HeadersBuilder._(this);
  }

  factory Headers.fromMap(Map<String, dynamic> items) {
    final headers = HeadersBuilder();
    items.forEach(headers.add);
    return headers.build();
  }

  factory Headers.fromList(List<Object> items) {
    final headers = HeadersBuilder();

    for (var i = 0; i < items.length; i += 2) {
      final key = items[i]?.toString();

      if (key != null && key.isNotEmpty) {
        try {
          headers.add(key, items[i + 1]);
        } catch (e) {
          // nada.
        }
      }
    }

    return headers.build();
  }

  @override
  String rightName(String name) {
    return name?.toLowerCase();
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
  String rightName(String name) {
    return name?.toLowerCase();
  }

  @override
  Object rightValue(Object value) {
    ArgumentError.checkNotNull(value);
    return value;
  }

  void addLine(String line) {
    final index = line.indexOf(':', 1);

    if (index != -1) {
      add(
        line.substring(0, index).trim(),
        line.substring(index + 1).trim(),
      );
    } else if (line.startsWith(':')) {
      // Work around empty header names and header names that start with a
      // colon (created by old broken SPDY versions of the response cache).
      add('', line.substring(1).trim()); // Empty header name.
    } else {
      add('', line); // No header name.
    }
  }

  @override
  Headers build() {
    return Headers._(items);
  }
}
