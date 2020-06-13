import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/push/sse/event.dart';

abstract class SseConnection implements Closeable {
  Stream<SseEvent> get stream;
}
