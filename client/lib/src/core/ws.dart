part of 'client.dart';

class _WebSocket implements WebSocket {
  @override
  final Request request;
  final List<String> protocols;
  final Duration pingInterval;

  _WebSocket(
    this.request, {
    this.protocols,
    this.pingInterval,
  });

  @override
  Future<WebSocketConnection> open() async {
    // ignore: close_sinks
    final ws = await io.WebSocket.connect(
      request.uri.toUriString(),
      protocols: protocols,
      headers: request.headers?.toMap(),
    );

    ws.pingInterval = pingInterval;

    return _WebSocketConnection(ws);
  }
}

class _WebSocketConnection implements WebSocketConnection {
  final io.WebSocket _ws;
  Stream _stream;

  _WebSocketConnection(io.WebSocket ws) : _ws = ws;

  @override
  void addString(String text) => _ws.add(text);

  @override
  void addBytes(List<int> bytes) => _ws.add(bytes);

  @override
  Future addStream(Stream stream) => _ws.addStream(stream);

  @override
  void addUtf8Text(List<int> bytes) => _ws.addUtf8Text(bytes);

  @override
  Future close([
    int code,
    String reason,
  ]) {
    return _ws.close(code, reason);
  }

  @override
  int get closeCode => _ws.closeCode;

  @override
  String get closeReason => _ws.closeReason;

  @override
  String get extensions => _ws.extensions;

  @override
  String get protocol => _ws.protocol;

  @override
  int get readyState => _ws.readyState;

  @override
  Future get done => _ws.done;

  @override
  Stream<dynamic> get stream => _stream ??= _ws.asBroadcastStream();
}
