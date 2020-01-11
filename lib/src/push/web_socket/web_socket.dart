import 'package:restio/restio.dart';
import 'package:restio/src/push/web_socket/connection.dart';

export 'connection.dart';

abstract class WebSocket {
  Request get request;

  Future<WebSocketConnection> open();
}
