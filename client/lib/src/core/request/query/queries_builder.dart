import 'package:restio/src/common/item_list_builder.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/query/query.dart';

class QueriesBuilder extends ItemListBuilder<Query> {
  final bool keepEqualSign;

  QueriesBuilder({
    List<Query> items,
    bool keepEqualSign = false,
  })  : keepEqualSign = keepEqualSign ?? false,
        super(items);

  @override
  Query createItem(
    String name,
    String value,
  ) {
    return Query(name, value);
  }

  @override
  Queries build() {
    return Queries(
      items: items,
      keepEqualSign: keepEqualSign,
    );
  }
}
