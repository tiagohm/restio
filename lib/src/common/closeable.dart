abstract class Closeable {
  Future<void> close();

  bool get isClosed;
}
