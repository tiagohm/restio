import 'package:restio/src/core/push/sse/connection.dart';
import 'package:restio/src/core/request/request.dart';

export 'connection.dart';
export 'event.dart';
export 'transformer.dart';

abstract class Sse {
  Request get request;

  Future<SseConnection> open();

  Duration get retryInterval;

  String get lastEventId;
}
