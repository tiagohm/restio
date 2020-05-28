import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/closeable.dart';

abstract class Connection<T> with EquatableMixin implements Closeable {
  final String scheme;
  final String host;
  final int port;
  final String ip;
  final T client;

  Connection({
    @required this.scheme,
    @required this.host,
    @required this.port,
    this.ip,
    @required this.client,
  })  : assert(scheme != null),
        assert(host != null),
        assert(port != null),
        assert(client != null);

  String get key => makeKey(scheme, host, port, ip);

  static String makeKey(
    String scheme,
    String host,
    int port, [
    String ip,
  ]) {
    final sb = StringBuffer();

    sb.write('$scheme:$host:$port');

    if (ip != null) {
      sb.write(':$ip');
    }

    return sb.toString();
  }

  @override
  List<Object> get props => [scheme, host, ip, port];
}
