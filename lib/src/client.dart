import 'dart:io';

import 'package:restio/src/authenticator.dart';
import 'package:restio/src/call.dart';
import 'package:restio/src/cancellable.dart';
import 'package:restio/src/client_adapter.dart';
import 'package:restio/src/client_certificate_jar.dart';
import 'package:restio/src/cookie_jar.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/interceptor_chain.dart';
import 'package:restio/src/interceptors/connect_interceptor.dart';
import 'package:restio/src/interceptors/cookie_interceptor.dart';
import 'package:restio/src/interceptors/follow_up_interceptor.dart';
import 'package:restio/src/listeners.dart';
import 'package:restio/src/proxy.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';
import 'package:meta/meta.dart';

class Restio {
  final Duration connectTimeout;
  final Duration writeTimeout;
  final Duration receiveTimeout;
  final List<Interceptor> interceptors;
  final List<Interceptor> networkInterceptors;
  final CookieJar cookieJar;
  final ClientAdapter adapter;
  final Authenticator auth;
  final bool followRedirects;
  final int maxRedirects;
  final bool verifySSLCertificate;
  final String userAgent;
  final Proxy proxy;
  final Uri baseUri;
  final bool withTrustedRoots;
  final ProgressListener<Request> onUploadProgress;
  final ProgressListener<Response> onDownloadProgress;
  final BadCertificateListener onBadCertificate;
  final bool isHttp2;
  final ClientCertificateJar clientCertificateJar;

  Restio({
    this.connectTimeout,
    this.writeTimeout,
    this.receiveTimeout,
    this.interceptors = const [],
    this.networkInterceptors = const [],
    this.cookieJar = CookieJar.noCookies,
    ClientAdapter adapter,
    this.auth,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.verifySSLCertificate = false,
    this.userAgent,
    this.proxy,
    this.baseUri,
    this.withTrustedRoots = true,
    this.onUploadProgress,
    this.onDownloadProgress,
    this.onBadCertificate,
    this.isHttp2 = false,
    this.clientCertificateJar,
  })  : assert(interceptors != null),
        assert(maxRedirects != null),
        assert(followRedirects != null),
        adapter = adapter ?? DefaultClientAdapter();

  Call newCall(Request request) {
    return _Call(client: this, request: request);
  }

  Restio copyWith({
    Duration connectTimeout,
    Duration writeTimeout,
    Duration receiveTimeout,
    List<Interceptor> interceptors,
    List<Interceptor> networkInterceptors,
    CookieJar cookieJar,
    ClientAdapter adapter,
    Authenticator auth,
    bool followRedirects,
    int maxRedirects,
    bool verifySSLCertificate,
    String userAgent,
    Proxy proxy,
    Uri baseUri,
    SecurityContext securityContext,
    bool withTrustedRoots,
    ProgressListener<Request> onUploadProgress,
    ProgressListener<Response> onDownloadProgress,
    BadCertificateListener onBadCertificate,
    bool isHttp2,
    ClientCertificateJar clientCertificateJar,
  }) {
    return Restio(
      connectTimeout: connectTimeout ?? this.connectTimeout,
      writeTimeout: writeTimeout ?? this.writeTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      interceptors: interceptors ?? this.interceptors,
      networkInterceptors: networkInterceptors ?? this.networkInterceptors,
      cookieJar: cookieJar ?? this.cookieJar,
      adapter: adapter ?? this.adapter,
      auth: auth ?? this.auth,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      verifySSLCertificate: verifySSLCertificate ?? this.verifySSLCertificate,
      userAgent: userAgent ?? this.userAgent,
      proxy: proxy ?? this.proxy,
      baseUri: baseUri ?? this.baseUri,
      withTrustedRoots: withTrustedRoots ?? this.withTrustedRoots,
      onUploadProgress: onUploadProgress ?? this.onUploadProgress,
      onDownloadProgress: onDownloadProgress ?? this.onDownloadProgress,
      onBadCertificate: onBadCertificate ?? this.onBadCertificate,
      isHttp2: isHttp2 ?? this.isHttp2,
      clientCertificateJar: clientCertificateJar ?? this.clientCertificateJar,
    );
  }
}

class _Call extends Call {
  final Restio client;
  @override
  final Request request;
  final _cancellable = Cancellable();  
  var _executed = false;
  var _executing = false;

  _Call({
    this.client,
    this.request,
  });

  @override
  void cancel(String message) {
    _cancellable.cancel(message);
  }

  @override
  Future<Response> execute() async {
    if (!_executing && !isCancelled) {
      _executing = true;

      final adapter = client.adapter;

      try {
        return await adapter.execute(client, this, _cancellable);
      } finally {
        _executed = true;
      }
    } else {
      throw Exception('Call has already been executed');
    }
  }

  @override
  bool get isExecuted => _executed;

  @override
  bool get isCancelled => _cancellable.isCancelled;
}

class DefaultClientAdapter extends ClientAdapter {
  @override
  @mustCallSuper
  Future<Response> execute(
    Restio client,
    Call call, [
    Cancellable cancellable,
  ]) async {
    final interceptors = [
      // Interceptors.
      if (client.interceptors != null)
        ...client.interceptors,
      // Redirects.
      FollowUpInterceptor(
        client: client,
      ),
      // Cookies.
      CookieInterceptor(
        cookieJar: client.cookieJar,
      ),
      // Network Interceptors.
      if (client.networkInterceptors != null)
        ...client.networkInterceptors,
      // Connection.
      ConnectInterceptor(
        client: client,
        cancellable: cancellable,
      ),
    ];

    final chain = InterceptorChain(
      call: call,
      request: call.request,
      interceptors: interceptors,
      index: 0,
    );

    return chain.proceed(call.request);
  }
}
