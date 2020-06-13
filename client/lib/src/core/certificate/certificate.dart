import 'package:equatable/equatable.dart';
import 'package:restio/src/common/glob_matcher.dart';

class Certificate extends Equatable {
  final String host;
  final int port;
  final List<int> certificate;
  final List<int> privateKey;
  final String password;

  const Certificate({
    this.host,
    this.certificate,
    this.privateKey,
    this.port,
    this.password,
  });

  bool matches(
    String host,
    int port,
  ) {
    return this.host == null ||
        (this.port == null || this.port == port) &&
            GlobMatcher(this.host).matches(host);
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
