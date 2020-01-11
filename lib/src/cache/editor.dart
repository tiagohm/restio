import 'dart:async';

abstract class Editor {
  StreamSink<List<int>> newSink(int index);

  Stream<List<int>> newSource(int index);

  Future<void> commit();

  Future<void> abort();
}
