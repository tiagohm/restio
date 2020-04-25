import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/item.dart';
import 'package:restio/src/common/item_list_builder.dart';

abstract class ItemList<T extends Item> extends Equatable {
  @protected
  final List<T> items;

  const ItemList(List<T> items) : items = items ?? const [];

  int get length => items.length;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  @protected
  bool compareName(String item, String param) => item == param;

  T operator [](int index) => items[index];

  String nameAt(int index) => items[index]?.name;

  String valueAt(int index) => items[index]?.value;

  bool has(String name) => first(name) != null;

  String value(String name) => first(name)?.value;

  T first(String name) {
    try {
      return items.firstWhere((item) => compareName(item.name, name));
    } catch (e) {
      return null;
    }
  }

  T last(String name) {
    try {
      return items.lastWhere((item) => compareName(item.name, name));
    } catch (e) {
      return null;
    }
  }

  List<T> all(String name) {
    return [
      for (final item in items) if (compareName(item.name, name)) item,
    ];
  }

  Set<String> names() {
    return {
      for (final item in items) item.name,
    };
  }

  List<String> values() {
    return [
      for (final item in items) item.value,
    ];
  }

  void forEach(void Function(T item) callback) {
    items.forEach(callback);
  }

  void copyTo(List<T> items) {
    items.addAll(items);
  }

  ItemListBuilder<T> toBuilder();

  @override
  List<Object> get props => items;
}
