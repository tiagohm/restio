import 'package:restio/src/common/item.dart';

class Query extends Item {
  @override
  final String name;
  @override
  final String value;

  const Query(this.name, this.value);

  @override
  bool getBool() => isEmpty || super.getBool();

  String toQueryString({
    bool keepEqualSign = false,
  }) {
    return keepEqualSign
        ? '$name=${isNotEmpty ? value : ''}'
        : '$name${isNotEmpty ? '=$value' : ''}';
  }

  String toEncodedQueryString({
    bool keepEqualSign = false,
  }) {
    final value = Uri.encodeQueryComponent(this.value);
    final name = Uri.encodeQueryComponent(this.name);
    return keepEqualSign
        ? '$name=${isNotEmpty ? value : ''}'
        : '$name${isNotEmpty ? '=$value' : ''}';
  }

  @override
  String toString() {
    return 'Query { name: $name, value: $value }';
  }
}
