import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/response/response.dart';

class ServerPush {
  final Headers headers;
  final Future<Response> response;

  ServerPush(this.headers, this.response);
}
