abstract class WebSocketConnection {
  void addString(String text);

  void addBytes(List<int> bytes);

  Future addStream(Stream stream);

  void addUtf8Text(List<int> bytes);

  Future close([
    int code,
    String reason,
  ]);

  int get closeCode;

  String get closeReason;

  String get extensions;

  String get protocol;

  int get readyState;

  Future get done;

  Stream<dynamic> get stream;
}
