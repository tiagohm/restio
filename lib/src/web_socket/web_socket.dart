import 'package:restio/restio.dart';
import 'package:restio/src/web_socket/connection.dart';

abstract class WebSocket {
  Request get request;

  Future<WebSocketConnection> open();
}