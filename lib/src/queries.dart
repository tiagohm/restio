import 'package:meta/meta.dart';
import 'package:restio/src/utils/string_pair_list.dart';

class Queries extends StringPairList {
  @protected
  @override
  final List<String> items;

  const Queries._(this.items);

  static const empty = Queries._([]);

  QueriesBuilder toBuilder() {
    return QueriesBuilder._(this);
  }

  factory Queries.fromMap(Map<String, dynamic> items) {
    final queries = QueriesBuilder();
    items.forEach(queries.add);
    return queries.build();
  }

  factory Queries.fromList(List<Object> items) {
    final queries = QueriesBuilder();

    for (var i = 0; i < items.length; i += 2) {
      final key = items[i]?.toString();

      if (key != null && key.isNotEmpty) {
        try {
          queries.add(key, items[i + 1]);
        } catch (e) {
          // nada.
        }
      }
    }

    return queries.build();
  }

  String toQueryString() {
    final sb = StringBuffer();

    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) {
        sb.write('&');
      }

      sb.write(items[i]);

      final value = items[i + 1];

      if (value != null) {
        sb.write('=');
        sb.write(value);
      }
    }

    return sb.toString();
  }

  @override
  String toString() {
    final sb = StringBuffer();

    sb.write('Queries {');

    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) {
        sb.write(', ');
      }

      sb..write(items[i])..write('=')..write(items[i + 1]);
    }

    sb.write('}');

    return sb.toString();
  }
}

class QueriesBuilder extends StringPairListBuilder<Queries> {
  QueriesBuilder() : super();

  QueriesBuilder._(Queries queries) {
    queries.copyToBuilder(this);
  }

  @override
  Queries build() {
    return Queries._(items);
  }
}
