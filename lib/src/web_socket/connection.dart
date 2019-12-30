import 'dart:io';

class WebSocketConnection {
  final WebSocket _ws;
  Stream _stream;

  WebSocketConnection(WebSocket ws) : _ws = ws;

  void addString(String text) => _ws.add(text);

  void addBytes(List<int> bytes) => _ws.add(bytes);

  Future addStream(Stream stream) => _ws.addStream(stream);

  void addUtf8Text(List<int> bytes) => _ws.addUtf8Text(bytes);

  Future close([int code, String reason]) => _ws.close(code, reason);

  int get closeCode => _ws.closeCode;

  String get closeReason => _ws.closeReason;

  String get extensions => _ws.extensions;

  String get protocol => _ws.protocol;

  int get readyState => _ws.readyState;

  Future get done => _ws.done;

  Stream<dynamic> get stream => _stream ??= _ws.asBroadcastStream();
}
