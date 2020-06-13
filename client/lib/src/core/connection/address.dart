import 'package:equatable/equatable.dart';
import 'package:ip/ip.dart';
import 'package:restio/src/core/proxy/proxy.dart';

class Address extends Equatable {
  final String scheme;
  final String host;
  final int port;
  final Proxy proxy;
  final IpAddress ip;

  const Address({
    this.scheme,
    this.host,
    this.port,
    this.proxy,
    this.ip,
  });

  @override
  List<Object> get props => [scheme, host, port, proxy, ip];
}
