import 'package:meta/meta.dart';
import 'package:restio/src/common/item.dart';
import 'package:restio/src/common/item_list.dart';

abstract class ItemListBuilder<T extends Item> {
  @protected
  final List<T> items;

  ItemListBuilder(List<T> items) : items = List.of(items ?? <T>[]);

  int get length => items.length;

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  void clear() {
    items.clear();
  }

  void addItem(T item) {
    items.add(item);
  }

  @protected
  T createItem(String name, String value);

  @protected
  bool compareName(String item, String param) => item == param;

  void add(
    String name,
    Object value,
  ) {
    if (value == null) {
      addItem(createItem(name, value));
    } else if (value is Iterable) {
      for (final item in value) {
        if (item == null) {
          addItem(createItem(name, null));
        } else if (item is String || item is num || item is bool) {
          addItem(createItem(name, '$item'));
        }
      }
    } else if (value is String || value is num || value is bool) {
      addItem(createItem(name, '$value'));
    }
  }

  void set(
    String name,
    Object value,
  ) {
    removeAll(name);
    add(name, value);
  }

  void remove(
    String name,
    Object value,
  ) {
    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name) && item.value == value) {
        items.removeAt(i);
        i--;
      }
    }
  }

  void removeAll(String name) {
    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name)) {
        items.removeAt(i);
        i--;
      }
    }
  }

  void removeAt(int index) {
    if (index < length) {
      items.removeAt(index);
    }
  }

  T at(int index) {
    if (index < length) {
      return items[index];
    } else {
      return null;
    }
  }

  T first(String name) {
    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name)) {
        return item;
      }
    }

    return null;
  }

  T last(String name) {
    for (var i = length - 1; i >= 0; i--) {
      final item = items[i];

      if (compareName(item.name, name)) {
        return item;
      }
    }

    return null;
  }

  void removeFirst(String name) {
    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name)) {
        items.removeAt(i);
        break;
      }
    }
  }

  void removeLast(String name) {
    for (var i = length - 1; i >= 0; i--) {
      final item = items[i];

      if (compareName(item.name, name)) {
        items.removeAt(i);
        break;
      }
    }
  }

  ItemList<T> build();
}
