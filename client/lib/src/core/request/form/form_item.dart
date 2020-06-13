import 'package:restio/src/common/item.dart';

class Field extends Item {
  @override
  final String name;
  @override
  final String value;

  const Field(this.name, this.value);

  @override
  String toString() {
    return 'Field { name: $name, value: $value }';
  }
}
