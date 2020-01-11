import 'dart:async';

class SourceSink extends StreamSink<List<int>> {
  final List<int> data;
  final _completer = Completer<List<int>>();
  var _closed = false;

  SourceSink(this.data);

  @override
  void add(List<int> event) {
    if (_closed) {
      throw StateError('Sink is closed');
    }

    data.addAll(event);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    if (_closed) {
      throw StateError('Sink is closed');
    }

    _closed = true;
    _completer.completeError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    if (_closed) {
      throw StateError('Sink is closed');
    }

    return stream.listen(data.addAll).asFuture();
  }

  @override
  Future close() async {
    if (_closed) {
      throw StateError('Sink is closed');
    }

    _closed = true;

    _completer.complete(data);
  }

  @override
  Future get done => _completer.future;
}
