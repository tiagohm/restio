import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:restio/src/common/closeable.dart';

class FileStreamSink implements StreamSink<List<int>>, Closeable {
  final IOSink _sink;
  final void Function() onError;

  FileStreamSink(
    File file, {
    this.onError,
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) : _sink = file.openWrite(mode: mode, encoding: encoding);

  @override
  void add(List<int> event) {
    _sink.add(event);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    onError?.call();
    _sink.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return _sink.addStream(stream);
  }

  @override
  Future<void> close() async {
    try {
      await _sink.flush();
    } catch (e) {
      // nada.
    } finally {
      await _sink.close();
    }
  }

  @override
  Future get done => _sink.done;
}
