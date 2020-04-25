import 'package:restio/src/common/item.dart';

class Query extends Item {
  @override
  final String name;
  @override
  final String value;

  const Query(this.name, this.value);

  @override
  bool getBool() => isEmpty || super.getBool();

  String toQueryString() {
    return '$name${isNotEmpty ? '=$value' : ''}';
  }

  String toEncodedQueryString() {
    final name = Uri.encodeQueryComponent(this.name);
    final value = isNotEmpty ? '=${Uri.encodeQueryComponent(this.value)}' : '';
    return '$name$value';
  }

  @override
  String toString() {
    return 'Query { name: $name, value: $value }';
  }
}
