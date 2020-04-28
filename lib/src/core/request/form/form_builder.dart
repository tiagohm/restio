import 'package:restio/src/common/item_list_builder.dart';
import 'package:restio/src/core/request/form/form_body.dart';
import 'package:restio/src/core/request/form/form_item.dart';

class FormBuilder extends ItemListBuilder<FormItem> {
  var charset = 'utf-8';

  FormBuilder([List<FormItem> items]) : super(items);

  @override
  FormBody build() {
    return FormBody(
      items: items,
      charset: charset ?? 'utf-8',
    );
  }

  @override
  FormItem createItem(
    String name,
    String value,
  ) {
    return FormItem(name, value);
  }
}
