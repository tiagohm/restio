abstract class ResponseBodyData {
  void pause();

  void resume();

  bool get isPaused;

  bool get isStopped;

  Stream<List<int>> get stream;

  Future<List<int>> compressed();

  Future<List<int>> decompressed();

  Future<String> string();

  Future<dynamic> json();
}
