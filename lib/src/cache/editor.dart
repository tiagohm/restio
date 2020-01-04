import 'dart:async';

abstract class Editor {
  StreamSink<List<int>> newSink(int index);

  Stream<List<int>> newSource(int index);

  void commit();

  void abort();
}
