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
      addItem(createItem(name, null));
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

  void addMap(Map<String, dynamic> items) {
    items?.forEach(add);
  }

  void addItemList(ItemList<T> items) {
    items.toBuilder().copyTo(this);
  }

  void addAll(List<T> items) {
    this.items.addAll(items);
  }

  void copyTo(ItemListBuilder<T> builder) {
    builder.addAll(items);
  }

  void set(
    String name,
    Object value,
  ) {
    removeAll(name);
    add(name, value);
  }

  List<T> remove(
    String name,
    Object value,
  ) {
    final removed = <T>[];

    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name) && item.value == value) {
        removed.add(items.removeAt(i));
        i--;
      }
    }

    return removed;
  }

  bool removeItem(T item) {
    return items.remove(item);
  }

  List<T> removeAll(String name) {
    final removed = <T>[];

    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name)) {
        removed.add(items.removeAt(i));
        i--;
      }
    }

    return removed;
  }

  T removeAt(int index) {
    if (index < length) {
      return items.removeAt(index);
    } else {
      return null;
    }
  }

  T at(int index) {
    return index < length ? items[index] : null;
  }

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

  T removeFirst(String name) {
    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (compareName(item.name, name)) {
        return items.removeAt(i);
      }
    }

    return null;
  }

  T removeLast(String name) {
    for (var i = length - 1; i >= 0; i--) {
      final item = items[i];

      if (compareName(item.name, name)) {
        return items.removeAt(i);
      }
    }

    return null;
  }

  ItemList<T> build();
}
