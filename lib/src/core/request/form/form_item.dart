import 'package:restio/src/common/item.dart';

class FormItem extends Item {
  @override
  final String name;
  @override
  final String value;

  const FormItem(this.name, this.value);

  @override
  String toString() {
    return 'FormItem { name: $name, value: $value }';
  }
}
