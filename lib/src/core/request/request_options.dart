import 'package:equatable/equatable.dart';
import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/certificate/certificate.dart';
import 'package:restio/src/core/dns/dns.dart';
import 'package:restio/src/core/proxy/proxy.dart';

class RequestOptions extends Equatable {
  final Duration connectTimeout;
  final Duration writeTimeout;
  final Duration receiveTimeout;
  final Authenticator auth;
  final bool followRedirects;
  final bool followSslRedirects;
  final int maxRedirects;
  final bool verifySSLCertificate;
  final String userAgent;
  final Proxy proxy;
  final Dns dns;
  final Certificate certificate;

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
    this.certificate,
    this.followSslRedirects,
  });

  static const empty = RequestOptions();

  static const default_ = RequestOptions(
    followRedirects: true,
    followSslRedirects: true,
    maxRedirects: 5,
    verifySSLCertificate: false,
  );

  RequestOptions copyWith({
    Duration connectTimeout,
    Duration writeTimeout,
    Duration receiveTimeout,
    Authenticator auth,
    bool followRedirects,
    bool followSslRedirects,
    int maxRedirects,
    bool verifySSLCertificate,
    String userAgent,
    Proxy proxy,
    Dns dns,
    Certificate certificate,
  }) {
    return RequestOptions(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      writeTimeout: writeTimeout ?? this.writeTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      auth: auth ?? this.auth,
      followRedirects: followRedirects ?? this.followRedirects,
      followSslRedirects: followSslRedirects ?? this.followSslRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      verifySSLCertificate: verifySSLCertificate ?? this.verifySSLCertificate,
      userAgent: userAgent ?? this.userAgent,
      proxy: proxy ?? this.proxy,
      dns: dns ?? this.dns,
      certificate: certificate ?? this.certificate,
    );
  }

  RequestOptions mergeWith(RequestOptions options) {
    return copyWith(
      connectTimeout: options.connectTimeout,
      writeTimeout: options.writeTimeout,
      receiveTimeout: options.receiveTimeout,
      auth: options.auth,
      followRedirects: options.followRedirects,
      followSslRedirects: options.followSslRedirects,
      maxRedirects: options.maxRedirects,
      verifySSLCertificate: options.verifySSLCertificate,
      userAgent: options.userAgent,
      proxy: options.proxy,
      dns: options.dns,
      certificate: options.certificate,
    );
  }

  @override
  List<Object> get props => [
        connectTimeout,
        writeTimeout,
        receiveTimeout,
        auth,
        followRedirects,
        followSslRedirects,
        maxRedirects,
        verifySSLCertificate,
        userAgent,
        proxy,
        dns,
        certificate,
      ];

  @override
  String toString() {
    return 'RequestOptions { connectTimeout: $connectTimeout, auth: $auth,'
        ' writeTimeout: $writeTimeout, receiveTimeout: $receiveTimeout,'
        ' followRedirects: $followRedirects, maxRedirects: $maxRedirects,'
        ' verifySSLCertificate: $verifySSLCertificate, userAgent: $userAgent,'
        ' proxy: $proxy, dns: $dns, followSslRedirects: $followSslRedirects }';
  }
}
