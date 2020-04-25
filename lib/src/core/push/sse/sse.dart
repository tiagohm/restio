import 'package:restio/src/core/push/sse/connection.dart';
import 'package:restio/src/core/request/request.dart';

abstract class Sse {
  Request get request;

  Future<SseConnection> open();
}
