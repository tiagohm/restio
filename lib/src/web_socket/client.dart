import 'dart:io';

import 'package:restio/src/web_socket/connection.dart';
import 'package:restio/src/web_socket/request.dart';

class WebSocketClient {
  final Duration pingInterval;

  WebSocketClient({
    this.pingInterval,
  });

  Future<WebSocketConnection> connect(WebSocketRequest request) async {
    assert(request != null);

    // ignore: close_sinks
    final ws = await WebSocket.connect(
      request.uri.toString(),
      protocols: request.protocols,
      headers: request.headers?.toMap(),
    );

    ws.pingInterval = pingInterval;

    return WebSocketConnection(this, ws);
  }

  WebSocketClient copyWith({
    Duration pingInterval,
  }) {
    return WebSocketClient(
      pingInterval: pingInterval,
    );
  }
}
