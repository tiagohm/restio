import 'package:restio/src/utils/string_pair_list.dart';

// ignore_for_file: avoid_returning_this

class Queries extends StringPairList {
  const Queries._(List<String> items) : super(items);

  QueriesBuilder toBuilder() {
    return QueriesBuilder._(this);
  }

  static Queries of(Map<String, dynamic> items) {
    final headers = QueriesBuilder();
    items.forEach(headers.add);
    return headers.build();
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

  QueriesBuilder._(Queries headers) {
    headers.copyToBuilder(this);
  }

  @override
  Queries build() {
    return Queries._(items);
  }
}
