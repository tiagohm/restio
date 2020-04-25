import 'dart:io';

import 'package:restio/src/common/item_list.dart';
import 'package:restio/src/core/request/header/header.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';

class Headers extends ItemList<Header> {
  const Headers([List<Header> items]) : super(items);

  static const empty = Headers();

  factory Headers.fromMap(Map<String, dynamic> items) {
    final headers = HeadersBuilder();
    items.forEach(headers.add);
    return headers.build();
  }

  @override
  bool compareName(String item, String param) {
    return super.compareName(item?.toLowerCase(), param);
  }

  @override
  bool has(String name) => super.has(name?.toLowerCase());

  @override
  Header first(String name) => super.first(name?.toLowerCase());

  @override
  Header last(String name) => super.last(name?.toLowerCase());

  @override
  List<Header> all(String name) => super.all(name?.toLowerCase());

  @override
  Set<String> names() {
    return {
      for (final item in items) item.name.toLowerCase(),
    };
  }

  int get contentLength =>
      first(HttpHeaders.contentLengthHeader)?.getInt() ?? -1;

  List<String> vary() {
    final items = all(HttpHeaders.varyHeader);
    final res = <String>[];

    for (final item in items) {
      if (item != null) {
        final fields = item.value.split(',');

        for (final field in fields) {
          res.add(field.trim().toLowerCase());
        }
      }
    }

    return res;
  }

  bool get hasVaryAll => vary().contains('*');

  Map<String, dynamic> toMap() {
    final res = <String, dynamic>{};

    for (final name in names()) {
      res[name] = List.of(all(name).map((item) => item.value));
    }

    return res;
  }

  @override
  HeadersBuilder toBuilder() {
    return HeadersBuilder(items);
  }

  @override
  String toString() {
    return 'Headers { items: $items }';
  }
}
