import 'package:equatable/equatable.dart';
import 'package:restio/src/core/auth/authenticator.dart';

class Proxy extends Equatable {
  final bool http;
  final bool https;
  final String host;
  final int port;
  final Authenticator auth;

  const Proxy({
    this.http = true,
    this.https = true,
    this.host,
    this.port = 80,
    this.auth,
  });

  @override
  List<Object> get props => [http, https, host, port, auth];
}
