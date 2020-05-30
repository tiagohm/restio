import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/closeable.dart';

abstract class Connection extends Equatable implements Closeable {
  final bool http2;
  final String scheme;
  final String host;
  final int port;
  final String ip;
  final Map<String, dynamic> data;

  const Connection({
    @required this.http2,
    @required this.scheme,
    @required this.host,
    @required this.port,
    this.ip,
    @required this.data,
  })  : assert(http2 != null),
        assert(scheme != null),
        assert(host != null),
        assert(port != null),
        assert(data != null);

  String get key => makeKey(http2 ? '2' : '1', scheme, host, port, ip);

  static String makeKey(
    String version,
    String scheme,
    String host,
    int port, [
    String ip,
  ]) {
    final sb = StringBuffer();

    sb.write('$version:$scheme:$host:$port');

    if (ip != null) {
      sb.write(':$ip');
    }

    return sb.toString();
  }

  @override
  List<Object> get props => [http2, scheme, host, ip, port];
}
