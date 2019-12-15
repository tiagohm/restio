import 'package:restio/src/authenticator.dart';

class Proxy {
  final bool http;
  final bool https;
  final String host;
  final int port;
  final Authenticator auth;

  Proxy({
    this.http = true,
    this.https = true,
    this.host,
    this.port = 80,
    this.auth,
  });
}
