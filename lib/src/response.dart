import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/src/cache/cache_control.dart';
import 'package:restio/src/challenge.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/redirect.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response_body.dart';

class Response {
  final String message;
  final int code;
  final Headers headers;
  final List<Cookie> cookies;
  final ResponseBody body;
  final int elapsedMilliseconds;
  final List<Challenge> challenges;
  final HttpConnectionInfo connectionInfo;
  final List<Redirect> redirects;

  /// É o Request criado pelo usuário (não sofreu nenhuma transformação).
  final Request originalRequest;

  /// É o Request que iniciou a chamada (transformado pelos interceptors: Cookies, Auth headers).
  final Request request;

  /// É o Request que realizou a chamada (transformado pelo ConnectInterceptor: BaseUri, DNS).
  final Request connectRequest;
  final CacheControl cacheControl;

  final DateTime receivedAt;
  final X509Certificate certificate;

  Response({
    this.request,
    this.message,
    this.code,
    this.headers,
    this.cookies,
    this.body,
    this.elapsedMilliseconds,
    this.connectionInfo,
    this.redirects,
    this.originalRequest,
    this.connectRequest,
    this.receivedAt,
    this.certificate,
  })  : challenges = _challenges(code, headers),
        cacheControl =
            CacheControl.parse(headers?.first(HttpHeaders.cacheControlHeader));

  bool get isSuccess => code != null && code >= 200 && code <= 299;

  bool get isError => code != null && code >= 400;

  bool get isRedirect {
    switch (code) {
      case HttpStatus.movedPermanently:
      case HttpStatus.movedTemporarily:
      case HttpStatus.permanentRedirect:
      case HttpStatus.temporaryRedirect:
      case HttpStatus.multipleChoices:
      case HttpStatus.seeOther:
        return true;
      default:
        return false;
    }
  }

  static List<Challenge> _challenges(
    int code,
    Headers headers,
  ) {
    final res = <Challenge>[];

    if (headers != null &&
        code == HttpStatus.unauthorized &&
        headers.has(HttpHeaders.wwwAuthenticateHeader)) {
      for (final header in headers.all(HttpHeaders.wwwAuthenticateHeader)) {
        res.addAll(Challenge.parse(header));
      }
    }

    return res;
  }

  bool get isCacheable {
    switch (code) {
      // These codes can be cached unless headers forbid it.
      case HttpStatus.ok:
      case HttpStatus.noContent:
      case HttpStatus.notFound:
      case HttpStatus.movedPermanently:
      case HttpStatus.methodNotAllowed:
      case HttpStatus.nonAuthoritativeInformation:
      case HttpStatus.multipleChoices:
      case HttpStatus.gone:
      case HttpStatus.requestUriTooLong:
      case HttpStatus.notImplemented:
      case HttpStatus.permanentRedirect:
        break;
      // These codes can only be cached with the right response headers.
      // http://tools.ietf.org/html/rfc7234#section-3
      // s-maxage is not checked because OkHttp is a private cache that should ignore s-maxage.
      case HttpStatus.movedTemporarily:
      case HttpStatus.temporaryRedirect:
        if (headers?.has(HttpHeaders.expiresHeader) == true ||
            cacheControl.maxAge.inSeconds != -1 ||
            cacheControl.isPublic ||
            cacheControl.isPrivate) {
          break;
        }
        return false;
      // All other codes cannot be cached.
      default:
        return false;
    }

    return !cacheControl.noStore;
  }

  Response copyWith({
    Request request,
    String message,
    int code,
    Headers headers,
    List<Cookie> cookies,
    ResponseBody body,
    int elapsedMilliseconds,
    HttpConnectionInfo connectionInfo,
    List<Redirect> redirects,
    Request originalRequest,
    Request connectRequest,
    DateTime receivedAt,
    X509Certificate certificate,
  }) {
    return Response(
      request: request ?? this.request,
      message: message ?? this.message,
      code: code ?? this.code,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      body: body ?? this.body,
      elapsedMilliseconds: elapsedMilliseconds ?? this.elapsedMilliseconds,
      connectionInfo: connectionInfo ?? this.connectionInfo,
      redirects: redirects ?? this.redirects,
      originalRequest: originalRequest ?? this.originalRequest,
      connectRequest: connectRequest ?? this.connectRequest,
      receivedAt: receivedAt ?? this.receivedAt,
      certificate: certificate ?? this.certificate,
    );
  }

  @override
  String toString() {
    return 'Response { body: $body, code: $code, elapsedMilliseconds: $elapsedMilliseconds, receivedAt: $receivedAt,'
        ' headers: $headers, cookies: $cookies, message: $message, request: $request,'
        ' connectionInfo: $connectionInfo, redirects: $redirects, originalRequest: $originalRequest,'
        ' connectRequest: $connectRequest }';
  }
}
