import 'package:equatable/equatable.dart';
import 'package:restio/src/headers.dart';

class WebSocketRequest extends Equatable {
  final Uri uri;
  final List<String> protocols;
  final Headers headers;

  const WebSocketRequest({
    this.uri,
    this.protocols,
    this.headers,
  });

  WebSocketRequest.url(
    String url, {
    this.protocols,
    this.headers,
  }) : uri = Uri.parse(url);

  WebSocketRequest copyWith({
    Uri uri,
    final List<String> protocols,
    final Headers headers,
  }) {
    return WebSocketRequest(
      uri: uri,
      protocols: protocols,
      headers: headers,
    );
  }

  @override
  List<Object> get props => [uri, protocols, headers];
}
