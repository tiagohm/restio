import 'package:equatable/equatable.dart';

class Event extends Equatable implements Comparable<Event> {
  /// An identifier that can be used to allow a client to replay
  /// missed Events by returning the Last-Event-Id header.
  /// Returns empty string if not required.
  final String id;

  /// The name of the event. Returns empty string if not required.
  final String event;

  /// The payload of the event.
  final String data;

  const Event({
    this.id,
    this.event,
    this.data,
  });

  const Event.message({
    this.id,
    this.data,
  }) : event = 'message';

  @override
  int compareTo(Event other) => id.compareTo(other.id);

  @override
  List<Object> get props => [id, event, data];

  @override
  String toString() {
    return 'Event {id: $id, event: $event, data: $data}';
  }
}
