import 'package:equatable/equatable.dart';

// ignore_for_file: avoid_returning_this

class Queries extends Equatable {
  final List<String> _items;

  Queries._(QueriesBuilder builder) : _items = builder._items ?? <String>[];

  int get length => _items.length ~/ 2;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  String nameAt(int index) {
    final realIndex = index * 2;
    return realIndex < _items.length ? _items[realIndex] : null;
  }

  String valueAt(int index) {
    final realIndex = index * 2 + 1;
    return realIndex < _items.length ? _items[realIndex] : null;
  }

  bool has(String name) {
    if (name == null || name.isEmpty) {
      return false;
    }

    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
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

    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
        return _items[i + 1];
      }
    }

    return null;
  }

  String last(String name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    for (var i = _items.length - 2; i >= 0; i -= 2) {
      if (_items[i] == name) {
        return _items[i + 1];
      }
    }

    return null;
  }

  List<String> all(String name) {
    if (name == null || name.isEmpty) {
      return null;
    }

    name = name;
    final res = <String>[];

    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
        res.add(_items[i + 1]);
      }
    }

    return res;
  }

  Set<String> names() {
    return {
      for (var i = 0; i < _items.length; i += 2) _items[i],
    };
  }

  List<String> values() {
    return [
      for (var i = 1; i < _items.length; i += 2) _items[i],
    ];
  }

  Map<String, List<String>> toMap() {
    final res = <String, List<String>>{};

    for (var i = 0; i < _items.length; i += 2) {
      res.putIfAbsent(_items[i], () => []).add(_items[i + 1]);
    }

    return res;
  }

  void forEach(void Function(String name, String value) f) {
    for (var i = 0; i < _items.length; i += 2) {
      f(_items[i], _items[i + 1]);
    }
  }

  QueriesBuilder toBuilder() {
    return QueriesBuilder._(this);
  }

  static Queries of(Map<String, dynamic> map) {
    final queries = QueriesBuilder();
    map.forEach(queries.add);
    return queries.build();
  }

  @override
  String toString() {
    final sb = StringBuffer();

    sb.write('Queries {');

    for (var i = 0; i < _items.length; i += 2) {
      if (i > 0) {
        sb.write(', ');
      }

      sb..write(_items[i])..write(': ')..write(_items[i + 1]);
    }

    sb.write('}');

    return sb.toString();
  }

  @override
  List<Object> get props => [_items];
}

class QueriesBuilder {
  final _items = <String>[];

  QueriesBuilder();

  QueriesBuilder._(Queries queries) {
    _items.addAll(queries._items);
  }

  QueriesBuilder add(String name, value) {
    if (name == null || name.isEmpty) {
      throw ArgumentError('name is null or empty');
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is String || item is num || item is bool) {
          _items.add(name);
          _items.add('$item'.trim());
        }
      }
    } else if (value is String || value is num || value is bool) {
      _items.add(name);
      _items.add('$value'.trim());
    }

    return this;
  }

  QueriesBuilder set(String name, value) {
    remove(name);
    add(name, value);
    return this;
  }

  QueriesBuilder remove(String name) {
    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
        _items.removeAt(i);
        _items.removeAt(i);
        i -= 2;
      }
    }

    return this;
  }

  QueriesBuilder removeAt(int index) {
    final realIndex = index * 2;

    if (realIndex < _items.length) {
      _items.removeAt(realIndex);
      _items.removeAt(realIndex);
    }

    return this;
  }

  QueriesBuilder removeFirst(String name) {
    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
        _items.removeAt(i);
        _items.removeAt(i);
        break;
      }
    }

    return this;
  }

  QueriesBuilder removeLast(String name) {
    for (var i = _items.length - 2; i >= 0; i -= 2) {
      if (_items[i] == name) {
        _items.removeAt(i);
        _items.removeAt(i);
        break;
      }
    }

    return this;
  }

  // ignore: use_to_and_as_if_applicable
  Queries build() {
    return Queries._(this);
  }
}
