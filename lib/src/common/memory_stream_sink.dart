import 'dart:async';

import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/common/memory_file.dart';

class MemoryStreamSink implements StreamSink<List<int>>, Closeable {
  final MemoryFile _data;
  final List<int> _temp;
  final void Function() onError;
  final _completer = Completer();

  MemoryStreamSink(
    MemoryFile data, {
    this.onError,
  })  : _data = data,
        _temp = <int>[];

  @override
  void add(List<int> event) {
    _temp.addAll(event);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    onError?.call();
    _completer.completeError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) async {
    _temp.addAll(await readStream(stream));
  }

  @override
  Future<void> close() async {
    _data.data = _temp;
    _completer.complete();
  }

  @override
  Future get done => _completer.future;
}
