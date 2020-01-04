import 'dart:io';

import 'package:ip/ip.dart';
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
  final List<Challenge> challenges;
  final HttpConnectionInfo connectionInfo;
  final List<Redirect> redirects;

  /// É o Request criado pelo usuário (não sofreu nenhuma transformação).
  final Request originalRequest;

  /// É o Request que iniciou a chamada (transformado pelos interceptors).
  final Request request;

  final CacheControl cacheControl;

  final DateTime sentAt;
  final DateTime receivedAt;
  final int spentMilliseconds;
  final int totalMilliseconds;

  final X509Certificate certificate;

  final IpAddress dnsIp;

  Response({
    this.request,
    this.message,
    this.code,
    this.headers,
    this.cookies,
    this.body,
    this.spentMilliseconds,
    this.totalMilliseconds,
    this.connectionInfo,
    this.redirects,
    this.originalRequest,
    this.sentAt,
    this.receivedAt,
    this.certificate,
    this.dnsIp,
  })  : challenges = _challenges(code, headers),
        cacheControl = CacheControl.parse(
                headers?.first(HttpHeaders.cacheControlHeader)) ??
            const CacheControl();

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

  bool isCacheable([Request request]) {
    request ??= originalRequest;

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
        if (headers.has(HttpHeaders.expiresHeader) ||
            cacheControl.hasMaxAge ||
            cacheControl.isPublic ||
            cacheControl.isPrivate) {
          break;
        }
        return false;
      // All other codes cannot be cached.
      default:
        return false;
    }

    return !cacheControl.noStore && !request.cacheControl.noStore;
  }

  bool get hasBody {
    // HEAD requests never yield a body regardless of the response headers.
    if (originalRequest.method == HttpMethod.head) {
      return false;
    }

    if ((code < HttpStatus.continue_ || code >= HttpStatus.ok) &&
        code != HttpStatus.noContent &&
        code != HttpStatus.notModified) {
      return true;
    }

    // If the Content-Length or Transfer-Encoding headers disagree with the response code, the
    // response is malformed. For best compatibility, we honor the headers.
    if (body.contentLength != -1 ||
        headers.first(HttpHeaders.transferEncodingHeader) == 'chunked') {
      return true;
    }

    return false;
  }

  Response copyWith({
    Request request,
    String message,
    int code,
    Headers headers,
    List<Cookie> cookies,
    ResponseBody body,
    int spentMilliseconds,
    int totalMilliseconds,
    HttpConnectionInfo connectionInfo,
    List<Redirect> redirects,
    Request originalRequest,
    DateTime sentAt,
    DateTime receivedAt,
    X509Certificate certificate,
    IpAddress dnsIp,
  }) {
    return Response(
      request: request ?? this.request,
      message: message ?? this.message,
      code: code ?? this.code,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      body: body ?? this.body,
      spentMilliseconds: spentMilliseconds ?? this.spentMilliseconds,
      totalMilliseconds: totalMilliseconds ?? this.totalMilliseconds,
      connectionInfo: connectionInfo ?? this.connectionInfo,
      redirects: redirects ?? this.redirects,
      originalRequest: originalRequest ?? this.originalRequest,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      certificate: certificate ?? this.certificate,
      dnsIp: dnsIp ?? this.dnsIp,
    );
  }

  @override
  String toString() {
    return 'Response { body: $body, code: $code, totalMilliseconds: $totalMilliseconds, spentMilliseconds: $spentMilliseconds, sentAt: $sentAt, receivedAt: $receivedAt,'
        ' headers: $headers, cookies: $cookies, message: $message, request: $request,'
        ' connectionInfo: $connectionInfo, redirects: $redirects, originalRequest: $originalRequest,'
        ' dnsIp: $dnsIp }';
  }
}
