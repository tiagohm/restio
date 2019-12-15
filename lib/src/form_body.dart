import 'package:restio/src/media_type.dart';
import 'package:restio/src/request_body.dart';

class FormBody implements RequestBody {
  final _data = <String>[];
  MediaType _contentType;

  FormBody({
    String charset,
  }) {
    _contentType = MediaType.formUrlEncoded.copyWith(charset: charset);
  }

  factory FormBody.fromMap(
    Map<String, dynamic> formItems, [
    String charset,
  ]) {
    final body = FormBody(charset: charset ?? 'utf-8');
    for (final name in formItems.keys) {
      final dynamic value = formItems[name];

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

  @override
  MediaType get contentType => _contentType;

  int get size => _data.length;

  @override
  Stream<List<int>> write() async* {
    final encoding = _contentType.encoding;

    for (var i = 0; i < _data.length; i++) {
      if (i > 0) {
        yield encoding.encode('&');
      }

      yield encoding.encode(_data[i]);
    }
  }

  void add(String name, String value) {
    if (name == null || name.isEmpty || value == null) return;
    _data.add('$name=$value');
  }

  @override
  String toString() {
    return 'FormBody { contentType: $_contentType, data: $_data }';
  }
}
