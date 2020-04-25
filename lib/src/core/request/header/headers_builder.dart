import 'package:restio/src/common/item_list_builder.dart';
import 'package:restio/src/core/request/header/header.dart';
import 'package:restio/src/core/request/header/headers.dart';

class HeadersBuilder extends ItemListBuilder<Header> {
  HeadersBuilder([List<Header> items]) : super(items);

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
  Header createItem(
    String name,
    String value,
  ) {
    return Header(name, value);
  }

  @override
  Headers build() {
    return Headers(items);
  }
}
