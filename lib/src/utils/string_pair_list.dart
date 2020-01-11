import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

// ignore_for_file: avoid_returning_this

@immutable
abstract class StringPairList extends Equatable {
  @protected
  final List<String> items;

  const StringPairList(List<String> items) : items = items ?? const [];

  int get length => items.length ~/ 2;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  bool get isCaseSensitive => true;

  String nameAt(int index) {
    final realIndex = index * 2;
    return realIndex < items.length ? items[realIndex] : null;
  }

  String valueAt(int index) {
    final realIndex = index * 2 + 1;
    return realIndex < items.length ? items[realIndex] : null;
  }

  bool has(String name) {
    if (name == null || name.isEmpty) {
      return false;
    }

    name = rightName(name);

    for (var i = 0; i < items.length; i += 2) {
      if (items[i] == name) {
        return true;
      }
    }

    return false;
  }

  String value(String name) => first(name);

  String first(String name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    name = rightName(name);

    for (var i = 0; i < items.length; i += 2) {
      if (items[i] == name) {
        return items[i + 1];
      }
    }

    return null;
  }

  String last(String name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    name = rightName(name);

    for (var i = items.length - 2; i >= 0; i -= 2) {
      if (items[i] == name) {
        return items[i + 1];
      }
    }

    return null;
  }

  List<String> all(String name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    name = rightName(name);

    return [
      for (var i = 0; i < items.length; i += 2)
        if (items[i] == name) items[i + 1],
    ];
  }

  Set<String> names() {
    return {
      for (var i = 0; i < items.length; i += 2) rightName(items[i]),
    };
  }

  List<String> values() {
    return [
      for (var i = 1; i < items.length; i += 2) items[i],
    ];
  }

  @protected
  String rightName(String name) {
    return isCaseSensitive ? name : name?.toLowerCase();
  }

  Map<String, List<String>> toMap() {
    final res = <String, List<String>>{};

    for (var i = 0; i < items.length; i += 2) {
      res.putIfAbsent(rightName(items[i]), () => []).add(items[i + 1]);
    }

    return res;
  }

  void forEach(void Function(String name, String value) f) {
    for (var i = 0; i < items.length; i += 2) {
      f(rightName(items[i]), items[i + 1]);
    }
  }

  void copyTo(List<String> items) {
    items.addAll(this.items);
  }

  void copyToBuilder(StringPairListBuilder builder) {
    builder.items.addAll(items);
  }

  @override
  List<Object> get props => [items];
}

abstract class StringPairListBuilder<L extends StringPairList> {
  @protected
  final items = <String>[];

  StringPairListBuilder();

  StringPairListBuilder.from(L list) {
    list.copyTo(items);
  }

  bool get isCaseSensitive => true;

  @protected
  String rightName(String name) {
    return isCaseSensitive ? name : name?.toLowerCase();
  }

  StringPairListBuilder<L> add(String name, value) {
    if (name == null || name.isEmpty) {
      throw ArgumentError('name is null or empty');
    }

    name = rightName(name);

    if (value is Iterable) {
      for (final item in value) {
        if (item is String || item is num || item is bool) {
          items.add(name);
          items.add('$item'.trim());
        }
      }
    } else if (value is String || value is num || value is bool) {
      items.add(name);
      items.add('$value'.trim());
    }

    return this;
  }

  StringPairListBuilder<L> set(String name, value) {
    remove(name);
    add(name, value);
    return this;
  }

  StringPairListBuilder<L> remove(String name) {
    name = rightName(name);

    for (var i = 0; i < items.length; i += 2) {
      if (items[i] == name) {
        items.removeAt(i);
        items.removeAt(i);
        i -= 2;
      }
    }

    return this;
  }

  StringPairListBuilder<L> removeAt(int index) {
    final realIndex = index * 2;

    if (realIndex < items.length) {
      items.removeAt(realIndex);
      items.removeAt(realIndex);
    }

    return this;
  }

  StringPairListBuilder<L> removeFirst(String name) {
    name = rightName(name);

    for (var i = 0; i < items.length; i += 2) {
      if (items[i] == name) {
        items.removeAt(i);
        items.removeAt(i);
        break;
      }
    }

    return this;
  }

  StringPairListBuilder<L> removeLast(String name) {
    name = rightName(name);

    for (var i = items.length - 2; i >= 0; i -= 2) {
      if (items[i] == name) {
        items.removeAt(i);
        items.removeAt(i);
        break;
      }
    }

    return this;
  }

  L build();
}
