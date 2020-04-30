import 'dart:async';
import 'dart:io' as io;

import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/cache/cache.dart';
import 'package:restio/src/core/call/call.dart';
import 'package:restio/src/core/call/cancellable.dart';
import 'package:restio/src/core/certificate/client_certificate_jar.dart';
import 'package:restio/src/core/cookie/cookie_jar.dart';
import 'package:restio/src/core/dns/dns.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/internal/bridge_interceptor.dart';
import 'package:restio/src/core/internal/connect_interceptor.dart';
import 'package:restio/src/core/internal/cookie_interceptor.dart';
import 'package:restio/src/core/internal/follow_up_interceptor.dart';
import 'package:restio/src/core/internal/interceptor_chain.dart';
import 'package:restio/src/core/listeners.dart';
import 'package:restio/src/core/proxy/proxy.dart';
import 'package:restio/src/core/push/sse/sse.dart';
import 'package:restio/src/core/push/ws/ws.dart';
import 'package:restio/src/core/redirect/redirect_policy.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

part 'call.dart';
part 'sse.dart';
part 'ws.dart';

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
  final List<RedirectPolicy> redirectPolicies;

  const Restio({
    this.connectTimeout,
    this.writeTimeout,
    this.receiveTimeout,
    this.interceptors,
    this.networkInterceptors,
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
    this.redirectPolicies,
  })  : assert(maxRedirects != null),
        assert(followRedirects != null);

  static const version = '0.6.0';

  Call newCall(Request request) {
    return _Call(client: this, request: request);
  }

  WebSocket newWebSocket(
    Request request, {
    List<String> protocols,
    Duration pingInterval,
  }) {
    return _WebSocket(
      request,
      protocols: protocols,
      pingInterval: pingInterval,
    );
  }

  Sse newSse(
    Request request, {
    String lastEventId,
    Duration retryInterval,
    int maxRetries,
  }) {
    return _Sse(
      this,
      request,
      lastEventId: lastEventId,
      retryInterval: retryInterval,
      maxRetries: maxRetries,
    );
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
    List<RedirectPolicy> redirectPolicies,
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
      redirectPolicies: redirectPolicies ?? this.redirectPolicies,
    );
  }
}
