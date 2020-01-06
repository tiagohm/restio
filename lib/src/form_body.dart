import 'package:restio/src/media_type.dart';
import 'package:restio/src/request_body.dart';
import 'package:restio/src/utils/string_pair_list.dart';

// ignore_for_file: avoid_returning_this

class FormBody extends StringPairList implements RequestBody {
  @override
  final MediaType contentType;

  FormBody._({
    List<String> items,
    String charset,
  })  : contentType = MediaType.formUrlEncoded.copyWith(charset: charset),
        super(items);

  FormBody({
    String charset,
  })  : contentType = MediaType.formUrlEncoded.copyWith(charset: charset),
        super(const []);

  factory FormBody.of(
    Map<String, dynamic> items, [
    String charset,
  ]) {
    final body = FormBodyBuilder();
    body.charset(charset);
    items.forEach(body.add);
    return body.build();
  }

  @override
  Stream<List<int>> write() async* {
    final encoding = contentType.encoding;

    for (var i = 0; i < items.length; i += 2) {
      if (i > 0) {
        yield encoding.encode('&');
      }

      yield encoding.encode(items[i]);
      yield encoding.encode('=');
      yield encoding.encode(items[i + 1]);
    }
  }

  @override
  String toString() {
    return 'FormBody { contentType: $contentType, items: $items }';
  }
}

class FormBodyBuilder extends StringPairListBuilder<FormBody> {
  String _charset = 'utf-8';

  FormBodyBuilder() : super();

  FormBodyBuilder._(FormBody body) {
    body.copyToBuilder(this);
  }

  FormBodyBuilder charset(String value) {
    _charset = value ?? 'utf-8';
    return this;
  }

  @override
  FormBody build() {
    return FormBody._(
      items: items,
      charset: _charset,
    );
  }
}
