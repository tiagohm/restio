import 'package:restio/src/media_type.dart';
import 'package:restio/src/request_body.dart';

class FormBody implements RequestBody {
  @override
  final MediaType contentType;
  final _data = <String>[];

  FormBody({
    String charset,
  }) : contentType = MediaType.formUrlEncoded.copyWith(charset: charset);

  factory FormBody.of(
    Map<String, dynamic> items, [
    String charset,
  ]) {
    final body = FormBody(charset: charset ?? 'utf-8');
    for (final name in items.keys) {
      final dynamic value = items[name];

      if (value is String) {
        body.add(name, value);
      } else if (value is List) {
        for (final item in value) {
          body.add(name, item.toString());
        }
      }
    }
    return body;
  }

  int get size => _data.length;

  @override
  Stream<List<int>> write() async* {
    final encoding = contentType.encoding;

    for (var i = 0; i < _data.length; i++) {
      if (i > 0) {
        yield encoding.encode('&');
      }

      yield encoding.encode(_data[i]);
    }
  }

  void add(
    String name,
    String value,
  ) {
    if (name == null || name.isEmpty || value == null) {
      return;
    }

    _data.add('$name=$value');
  }

  @override
  String toString() {
    return 'FormBody { contentType: $contentType, data: $_data }';
  }
}
