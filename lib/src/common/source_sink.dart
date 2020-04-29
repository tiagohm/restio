import 'dart:async';

import 'package:restio/src/common/closeable.dart';

class SourceSink extends StreamSink<List<int>> implements Closeable {
  final List<int> data;
  final _completer = Completer<List<int>>();
  var _isClosed = false;

  SourceSink(this.data);

  @override
  void add(List<int> event) {
    data.addAll(event);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    _isClosed = true;
    _completer.completeError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return stream.listen(data.addAll).asFuture();
  }

  @override
  Future close() async {
    if (isClosed) {
      return;
    }

    _isClosed = true;
    _completer.complete(data);
  }

  @override
  bool get isClosed => _isClosed;

  @override
  Future get done => _completer.future;
}
