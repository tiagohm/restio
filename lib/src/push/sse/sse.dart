import 'package:restio/src/request.dart';
import 'package:restio/src/push/sse/connection.dart';

export 'connection.dart';
export 'event.dart';

abstract class Sse {
  Request get request;

  Future<SseConnection> open();
}
