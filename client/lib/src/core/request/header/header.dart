import 'dart:io';

import 'package:restio/src/common/item.dart';

class Header extends Item {
  @override
  final String name;
  @override
  final String value;

  const Header(this.name, this.value);

  DateTime get asDateTime {
    return isEmpty ? null : HttpDate.parse(value);
  }

  @override
  String toString() {
    return 'Header { name: $name, value: $value }';
  }
}
