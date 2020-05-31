import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/connection/address.dart';

abstract class Connection extends Equatable implements Closeable {
  final bool http2;
  final Address address;
  final List data;

  const Connection({
    @required this.http2,
    @required this.address,
    @required this.data,
  })  : assert(http2 != null),
        assert(address != null),
        assert(data != null);

  String get key =>
      makeKey(http2 ? '2' : '1', address.scheme, address.host, address.port);

  static String makeKey(
    String version,
    String scheme,
    String host,
    int port,
  ) {
    final sb = StringBuffer();

    sb.write('$version:$scheme:$host:$port');

    return sb.toString();
  }

  @override
  List<Object> get props => [http2, address];
}
