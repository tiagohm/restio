import 'package:equatable/equatable.dart';

// ignore_for_file: avoid_returning_this

class Headers extends Equatable {
  final List<String> _items;

  Headers._(HeadersBuilder builder) : _items = builder._items ?? <String>[];

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

    name = name.toLowerCase();

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

    name = name.toLowerCase();

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

    name = name.toLowerCase();

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

    name = name.toLowerCase();
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

  HeadersBuilder toBuilder() {
    return HeadersBuilder._(this);
  }

  static Headers of(Map<String, dynamic> map) {
    final headers = HeadersBuilder();
    map.forEach(headers.add);
    return headers.build();
  }

  @override
  String toString() {
    final sb = StringBuffer();

    sb.write('Headers {');

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

class HeadersBuilder {
  final _items = <String>[];

  HeadersBuilder();

  HeadersBuilder._(Headers headers) {
    _items.addAll(headers._items);
  }

  HeadersBuilder add(String name, value) {
    if (name == null || name.isEmpty) {
      throw ArgumentError('name is null or empty');
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is String || item is num || item is bool) {
          _items.add(name.toLowerCase());
          _items.add('$item'.trim());
        }
      }
    } else if (value is String || value is num || value is bool) {
      _items.add(name.toLowerCase());
      _items.add('$value'.trim());
    }

    return this;
  }

  HeadersBuilder set(String name, value) {
    remove(name);
    add(name, value);
    return this;
  }

  HeadersBuilder remove(String name) {
    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
        _items.removeAt(i);
        _items.removeAt(i);
        i -= 2;
      }
    }

    return this;
  }

  HeadersBuilder removeAt(int index) {
    final realIndex = index * 2;

    if (realIndex < _items.length) {
      _items.removeAt(realIndex);
      _items.removeAt(realIndex);
    }

    return this;
  }

  HeadersBuilder removeFirst(String name) {
    for (var i = 0; i < _items.length; i += 2) {
      if (_items[i] == name) {
        _items.removeAt(i);
        _items.removeAt(i);
        break;
      }
    }

    return this;
  }

  HeadersBuilder removeLast(String name) {
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
  Headers build() {
    return Headers._(this);
  }
}
