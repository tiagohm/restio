import 'package:restio/src/core/push/sse/connection.dart';
import 'package:restio/src/core/request/request.dart';

export 'connection.dart';
export 'event.dart';
export 'retry.dart';
export 'transformer.dart';

abstract class Sse {
  Request get request;

  Future<SseConnection> open();
}
