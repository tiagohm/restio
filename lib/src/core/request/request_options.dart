import 'package:equatable/equatable.dart';
import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/dns/dns.dart';
import 'package:restio/src/core/proxy/proxy.dart';

class RequestOptions extends Equatable {
  final Duration connectTimeout;
  final Duration writeTimeout;
  final Duration receiveTimeout;
  final Authenticator auth;
  final bool followRedirects;
  final int maxRedirects;
  final bool verifySSLCertificate;
  final String userAgent;
  final Proxy proxy;
  final Dns dns;
  
  const RequestOptions({
    this.connectTimeout,
    this.writeTimeout,
    this.receiveTimeout,
    this.auth,
    this.followRedirects,
    this.maxRedirects,
    this.verifySSLCertificate,
    this.userAgent,
    this.proxy,
    this.dns,
  });

  static const empty = RequestOptions();

  static const default_ = RequestOptions(
    followRedirects: true,
    maxRedirects: 5,
    verifySSLCertificate: false,
  );

  RequestOptions copyWith({
    Duration connectTimeout,
    Duration writeTimeout,
    Duration receiveTimeout,
    Authenticator auth,
    bool followRedirects,
    int maxRedirects,
    bool verifySSLCertificate,
    String userAgent,
    Proxy proxy,
    Dns dns,
  }) {
    return RequestOptions(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      writeTimeout: writeTimeout ?? this.writeTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      auth: auth ?? this.auth,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      verifySSLCertificate: verifySSLCertificate ?? this.verifySSLCertificate,
      userAgent: userAgent ?? this.userAgent,
      proxy: proxy ?? this.proxy,
      dns: dns ?? this.dns,
    );
  }

  RequestOptions mergeWith(RequestOptions options) {
    return copyWith(
      connectTimeout: options.connectTimeout,
      writeTimeout: options.writeTimeout,
      receiveTimeout: options.receiveTimeout,
      auth: options.auth,
      followRedirects: options.followRedirects,
      maxRedirects: options.maxRedirects,
      verifySSLCertificate: options.verifySSLCertificate,
      userAgent: options.userAgent,
      proxy: options.proxy,
      dns: options.dns,
    );
  }

  @override
  List<Object> get props => [
        connectTimeout,
        writeTimeout,
        receiveTimeout,
        auth,
        followRedirects,
        maxRedirects,
        verifySSLCertificate,
        userAgent,
        proxy,
        dns,
      ];
}
