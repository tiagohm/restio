import 'dart:convert';

import 'package:restio/src/helpers.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/request_body.dart';
import 'package:restio/src/utils/string_pair_list.dart';

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

      yield _encodeForm(items[i], encoding);
      yield encoding.encode('=');
      yield _encodeForm(items[i + 1], encoding);
    }
  }

  static List<int> _encodeForm(
    String input,
    Encoding encoding,
  ) {
    return canonicalize(
      input,
      formEncodeSet,
      plusIsSpace: true,
      encoding: encoding,
    );
  }

  FormBodyBuilder toBuilder() {
    return FormBodyBuilder._(this);
  }

  @override
  List<Object> get props => [items, contentType];

  @override
  String toString() {
    return 'FormBody { contentType: $contentType, items: $items }';
  }
}

class FormBodyBuilder extends StringPairListBuilder<FormBody> {
  var _charset = 'utf-8';

  FormBodyBuilder() : super();

  FormBodyBuilder._(FormBody body) {
    body.copyToBuilder(this);
  }

  void charset(String value) {
    _charset = value ?? 'utf-8';
  }

  @override
  FormBody build() {
    return FormBody._(
      items: items,
      charset: _charset,
    );
  }
}
