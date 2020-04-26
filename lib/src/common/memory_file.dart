class MemoryFile {
  List<int> data;

  MemoryFile([List<int> data]) : data = data ?? <int>[];

  int get length => data.length;

  void copyTo(MemoryFile m) {
    m.data = List.of(data);
  }

  void delete() {
    data = null;
  }

  bool get exists => data != null;
}
