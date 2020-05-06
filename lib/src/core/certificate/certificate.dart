import 'package:equatable/equatable.dart';
import 'package:globbing/globbing.dart';

class Certificate extends Equatable {
  final String host;
  final int port;
  final List<int> certificate;
  final List<int> privateKey;
  final String password;

  const Certificate(
    this.host,
    this.certificate,
    this.privateKey, {
    this.port,
    this.password,
  })  : assert(host != null),
        assert(certificate != null),
        assert(privateKey != null);

  bool matches(
    String host,
    int port,
  ) {
    return (this.port == null || this.port == port) &&
        Glob(this.host).match(host);
  }

  @override
  List<Object> get props => [
        host,
        port,
        certificate,
        privateKey,
        password,
      ];
}
