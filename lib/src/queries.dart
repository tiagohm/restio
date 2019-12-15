class Queries {
  final List<String> _namesAndValues;

  Queries._(QueriesBuilder builder)
      : _namesAndValues = builder._namesAndValues ?? <String>[];

  int get length => _namesAndValues.length ~/ 2;

  bool get isEmpty => length == 0;

  bool get isNotEmpty => !isEmpty;

  String nameAt(int index) {
    final realIndex = index * 2;
    return realIndex < _namesAndValues.length
        ? _namesAndValues[realIndex]
        : null;
  }

  String valueAt(int index) {
    final realIndex = index * 2 + 1;
    return realIndex < _namesAndValues.length
        ? _namesAndValues[realIndex]
        : null;
  }

  bool has(String name) {
    if (name == null || name.isEmpty) {
      return false;
    }

    for (var i = 0; i < _namesAndValues.length; i += 2) {
      if (_namesAndValues[i] == name) return true;
    }

    return false;
  }

  String value(String name) => first(name);

  String first(String name) {
    if (name == null || name.isEmpty) return null;

    for (var i = 0; i < _namesAndValues.length; i += 2) {
      if (_namesAndValues[i] == name) return _namesAndValues[i + 1];
    }

    return null;
  }

  String last(String name) {
    if (name == null || name.isEmpty) return null;

    for (var i = _namesAndValues.length - 2; i >= 0; i -= 2) {
      if (_namesAndValues[i] == name) return _namesAndValues[i + 1];
    }

    return null;
  }

  List<String> all(String name) {
    if (name == null || name.isEmpty) return null;

    name = name;
    final res = <String>[];

    for (var i = 0; i < _namesAndValues.length; i += 2) {
      if (_namesAndValues[i] == name) res.add(_namesAndValues[i + 1]);
    }

    return res;
  }

  Set<String> names() {
    return {
      for (var i = 0; i < _namesAndValues.length; i += 2) _namesAndValues[i],
    };
  }

  List<String> values() {
    return [
      for (var i = 1; i < _namesAndValues.length; i += 2) _namesAndValues[i],
    ];
  }

  Map<String, List<String>> toMap() {
    final res = <String, List<String>>{};

    for (var i = 0; i < _namesAndValues.length; i += 2) {
      res.putIfAbsent(_namesAndValues[i], () => [])
        ..add(_namesAndValues[i + 1]);
    }

    return res;
  }

  void forEach(void Function(String name, String value) f) {
    for (var i = 0; i < _namesAndValues.length; i += 2) {
      f(_namesAndValues[i], _namesAndValues[i + 1]);
    }
  }

  QueriesBuilder builder() {
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

    for (var i = 0; i < _namesAndValues.length; i += 2) {
      if (i > 0) sb.write(', ');
      sb..write(_namesAndValues[i])..write(': ')..write(_namesAndValues[i + 1]);
    }

    sb.write('}');

    return sb.toString();
  }
}

class QueriesBuilder {
  final _namesAndValues = <String>[];

  QueriesBuilder();

  QueriesBuilder._(Queries queries) {
    _namesAndValues.addAll(queries._namesAndValues);
  }

  QueriesBuilder add(String name, dynamic value) {
    if (name == null || name.isEmpty) {
      throw ArgumentError('name is null or empty');
    }

    if (value is Iterable) {
      for (final item in value) {
        if (item is String || item is num || item is bool) {
          _namesAndValues.add(name);
          _namesAndValues.add('$item'.trim());
        }
      }
    } else if (value is String || value is num || value is bool) {
      _namesAndValues.add(name);
      _namesAndValues.add('$value'.trim());
    }

    return this;
  }

  QueriesBuilder set(String name, dynamic value) {
    remove(name);
    add(name, value);
    return this;
  }

  QueriesBuilder remove(String name) {
    for (var i = 0; i < _namesAndValues.length; i += 2) {
      if (_namesAndValues[i] == name) {
        _namesAndValues.removeAt(i);
        _namesAndValues.removeAt(i);
        i -= 2;
      }
    }

    return this;
  }

  QueriesBuilder removeAt(int index) {
    final realIndex = index * 2;

    if (realIndex < _namesAndValues.length) {
      _namesAndValues.removeAt(realIndex);
      _namesAndValues.removeAt(realIndex);
    }

    return this;
  }

  QueriesBuilder removeFirst(String name) {
    for (var i = 0; i < _namesAndValues.length; i += 2) {
      if (_namesAndValues[i] == name) {
        _namesAndValues.removeAt(i);
        _namesAndValues.removeAt(i);
        break;
      }
    }

    return this;
  }

  QueriesBuilder removeLast(String name) {
    for (var i = _namesAndValues.length - 2; i >= 0; i -= 2) {
      if (_namesAndValues[i] == name) {
        _namesAndValues.removeAt(i);
        _namesAndValues.removeAt(i);
        break;
      }
    }

    return this;
  }

  Queries build() {
    return Queries._(this);
  }
}
