import 'dart:async';
import 'dart:io' as io;

import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/cache/cache.dart';
import 'package:restio/src/core/call.dart';
import 'package:restio/src/core/client_certificate_jar.dart';
import 'package:restio/src/core/cookie_jar.dart';
import 'package:restio/src/core/dns/dns.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/listeners.dart';
import 'package:restio/src/core/proxy.dart';
import 'package:restio/src/core/push/sse/sse.dart';
import 'package:restio/src/core/push/ws/ws.dart';
import 'package:restio/src/core/real_call.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

part 'ws.dart';
part 'sse.dart';

class Restio {
  final Duration connectTimeout;
  final Duration writeTimeout;
  final Duration receiveTimeout;
  final List<Interceptor> interceptors;
  final List<Interceptor> networkInterceptors;
  final CookieJar cookieJar;
  final Authenticator auth;
  final bool followRedirects;
  final int maxRedirects;
  final bool verifySSLCertificate;
  final String userAgent;
  final Proxy proxy;
  final bool withTrustedRoots;
  final ProgressCallback<Request> onUploadProgress;
  final ProgressCallback<Response> onDownloadProgress;
  final BadCertificateCallback onBadCertificate;
  final bool http2;
  final ClientCertificateJar clientCertificateJar;
  final Dns dns;
  final Cache cache;

  Restio({
    this.connectTimeout,
    this.writeTimeout,
    this.receiveTimeout,
    this.interceptors = const [],
    this.networkInterceptors = const [],
    this.cookieJar,
    this.auth,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.verifySSLCertificate = false,
    this.userAgent,
    this.proxy,
    this.withTrustedRoots = true,
    this.onUploadProgress,
    this.onDownloadProgress,
    this.onBadCertificate,
    this.http2 = false,
    this.clientCertificateJar,
    this.dns,
    this.cache,
  })  : assert(interceptors != null),
        assert(maxRedirects != null),
        assert(followRedirects != null);

  static const version = '0.6.0';

  Call newCall(Request request) {
    return RealCall(client: this, request: request);
  }

  WebSocket newWebSocket(
    Request request, {
    List<String> protocols,
    Duration pingInterval,
  }) {
    return RealWebSocket(
      request,
      protocols: protocols,
      pingInterval: pingInterval,
    );
  }

  Sse newSse(Request request) {
    return RealSse(this, request);
  }

  Restio copyWith({
    Duration connectTimeout,
    Duration writeTimeout,
    Duration receiveTimeout,
    List<Interceptor> interceptors,
    List<Interceptor> networkInterceptors,
    CookieJar cookieJar,
    Authenticator auth,
    bool followRedirects,
    int maxRedirects,
    bool verifySSLCertificate,
    String userAgent,
    Proxy proxy,
    io.SecurityContext securityContext,
    bool withTrustedRoots,
    ProgressCallback<Request> onUploadProgress,
    ProgressCallback<Response> onDownloadProgress,
    BadCertificateCallback onBadCertificate,
    bool http2,
    ClientCertificateJar clientCertificateJar,
    Dns dns,
    Cache cache,
  }) {
    return Restio(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      writeTimeout: writeTimeout ?? this.writeTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      interceptors: interceptors ?? this.interceptors,
      networkInterceptors: networkInterceptors ?? this.networkInterceptors,
      cookieJar: cookieJar ?? this.cookieJar,
      auth: auth ?? this.auth,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      verifySSLCertificate: verifySSLCertificate ?? this.verifySSLCertificate,
      userAgent: userAgent ?? this.userAgent,
      proxy: proxy ?? this.proxy,
      withTrustedRoots: withTrustedRoots ?? this.withTrustedRoots,
      onUploadProgress: onUploadProgress ?? this.onUploadProgress,
      onDownloadProgress: onDownloadProgress ?? this.onDownloadProgress,
      onBadCertificate: onBadCertificate ?? this.onBadCertificate,
      http2: http2 ?? this.http2,
      clientCertificateJar: clientCertificateJar ?? this.clientCertificateJar,
      dns: dns ?? this.dns,
      cache: cache ?? this.cache,
    );
  }
}
