import 'package:restio/src/common/item_list.dart';
import 'package:restio/src/core/request/query/queries_builder.dart';
import 'package:restio/src/core/request/query/query.dart';

class Queries extends ItemList<Query> {
  final bool keepEqualSign;

  const Queries({
    List<Query> items,
    bool keepEqualSign = false,
  })  : keepEqualSign = keepEqualSign ?? false,
        super(items);

  static const empty = Queries();

  factory Queries.fromMap(
    Map<String, dynamic> items, {
    bool keepEqualSign = false,
  }) {
    final builder = QueriesBuilder(keepEqualSign: keepEqualSign);
    items.forEach(builder.add);
    return builder.build();
  }

  String toQueryString({
    bool insertQuestionMark = false,
    bool encode = false,
  }) {
    final sb = StringBuffer();

    if (isNotEmpty && insertQuestionMark) {
      sb.write('?');
    }

    for (var i = 0; i < length; i++) {
      final item = items[i];

      if (i > 0) {
        sb.write('&');
      }

      sb.write(encode
          ? item.toEncodedQueryString(keepEqualSign: keepEqualSign)
          : item.toQueryString(keepEqualSign: keepEqualSign));
    }

    return sb.toString();
  }

  @override
  QueriesBuilder toBuilder() {
    return QueriesBuilder(
      items: items,
      keepEqualSign: keepEqualSign,
    );
  }

  @override
  String toString() {
    return 'Queries { items: $items }';
  }
}
