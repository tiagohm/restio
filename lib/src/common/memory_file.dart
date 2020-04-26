class MemoryFile {
  List<int> data;

  MemoryFile([this.data]);

  int get length => data.length;

  void copyTo(MemoryFile m) {
    m.data = List.of(data);
  }

  void delete() {
    data = null;
  }

  bool get exists => data != null;
}
