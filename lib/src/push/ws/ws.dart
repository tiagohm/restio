import 'package:restio/restio.dart';
import 'package:restio/src/push/ws/connection.dart';

export 'connection.dart';

abstract class WebSocket {
  Request get request;

  Future<WebSocketConnection> open();
}
