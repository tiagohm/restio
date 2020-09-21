import 'dart:convert' as convert;
import 'dart:io';

import 'package:ip/ip.dart';
import 'package:meta/meta.dart';
import 'package:restio/restio.dart';
import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/common/pausable.dart';
import 'package:restio/src/core/redirect/redirect.dart';
import 'package:restio/src/core/request/header/cache_control.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/http_method.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/challenge.dart';
import 'package:restio/src/core/response/server_push.dart';

part 'response_body.dart';

class Response implements Closeable {
  final String message;
  final int code;
  final Headers headers;
  final List<Cookie> cookies;
  final ResponseBody body;
  final List<Challenge> challenges;
  final int localPort;
  final List<Redirect> redirects;
  final Stream<ServerPush> pushes;

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

  final IpAddress address;

  final Response networkResponse;
  final Response cacheResponse;

  var _isClosed = false;

  final Future<void> Function() onClose;

  Response({
    this.request,
    this.message = '',
    @required this.code,
    this.headers = Headers.empty,
    @required this.body,
    this.spentMilliseconds = 0,
    this.totalMilliseconds = 0,
    this.localPort,
    this.redirects = const [],
    this.originalRequest,
    this.sentAt,
    this.receivedAt,
    this.certificate,
    this.address,
    CacheControl cacheControl,
    this.networkResponse,
    this.cacheResponse,
    this.onClose,
    this.pushes,
  })  : challenges = _challenges(code, headers),
        cacheControl = cacheControl ??
            CacheControl.fromHeaders(headers) ??
            CacheControl.empty,
        cookies = _cookies(request?.uri, headers);

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
        res.addAll(Challenge.parse(header.value));
      }
    }

    return res;
  }

  bool canCache([Request request]) {
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
      // s-maxage is not checked because OkHttp is a private cache
      // that should ignore s-maxage.
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

  /// Returns true if the response headers and status indicate that
  /// this response has a body.
  bool get hasBody {
    if (body == null) {
      return false;
    }

    // HEAD requests never yield a body regardless of the response headers.
    if (request.method == HttpMethod.head) {
      return false;
    }

    if ((code < HttpStatus.continue_ || code >= HttpStatus.ok) &&
        code != HttpStatus.noContent &&
        code != HttpStatus.notModified) {
      return true;
    }

    // If the Content-Length or Transfer-Encoding headers disagree
    // with the response code, the response is malformed.
    // For best compatibility, we honor the headers.
    if (body.contentLength != -1 ||
        headers.value(HttpHeaders.transferEncodingHeader) == 'chunked') {
      return true;
    }

    return false;
  }

  static List<Cookie> _cookies(
    RequestUri uri,
    Headers headers,
  ) {
    final cookies = <Cookie>[];

    if (uri != null) {
      headers?.forEach((item) {
        if (headers.compareName(item.name, 'set-cookie')) {
          try {
            final cookie = Cookie.fromSetCookieValue(item.value);

            if (cookie.name != null && cookie.name.isNotEmpty) {
              final domain = cookie.domain == null
                  ? uri.host
                  : cookie.domain.startsWith('.')
                      ? cookie.domain.substring(1)
                      : cookie.domain;
              final newCookie = Cookie(cookie.name, cookie.value)
                ..expires = cookie.expires
                ..maxAge = cookie.maxAge
                ..domain = domain
                ..path = cookie.path ?? uri.path
                ..secure = cookie.secure
                ..httpOnly = cookie.httpOnly;
              // Adiciona à lista de cookies a salvar.
              cookies.add(newCookie);
            }
          } catch (e) {
            // nada.
          }
        }
      });
    }

    return cookies;
  }

  Response copyWith({
    Request request,
    String message,
    int code,
    Headers headers,
    ResponseBody body,
    int spentMilliseconds,
    int totalMilliseconds,
    int localPort,
    List<Redirect> redirects,
    Request originalRequest,
    DateTime sentAt,
    DateTime receivedAt,
    X509Certificate certificate,
    IpAddress address,
    CacheControl cacheControl,
    Response networkResponse,
    Response cacheResponse,
    Future<void> Function() onClose,
    Stream<ServerPush> pushes,
  }) {
    return Response(
      request: request ?? this.request,
      message: message ?? this.message,
      code: code ?? this.code,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      spentMilliseconds: spentMilliseconds ?? this.spentMilliseconds,
      totalMilliseconds: totalMilliseconds ?? this.totalMilliseconds,
      localPort: localPort ?? this.localPort,
      redirects: redirects ?? this.redirects,
      originalRequest: originalRequest ?? this.originalRequest,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      certificate: certificate ?? this.certificate,
      address: address ?? this.address,
      cacheControl: cacheControl ?? this.cacheControl,
      networkResponse: networkResponse ?? this.networkResponse,
      cacheResponse: cacheResponse ?? this.cacheResponse,
      onClose: onClose ?? this.onClose,
      pushes: pushes ?? this.pushes,
    );
  }

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    _isClosed = true;

    try {
      // Libera a conexão para a próxima requisição.
      await body?.drain();
    } catch (e) {
      // nada.
    }

    try {
      // Libera os Server Pushes.
      await pushes?.drain();
    } catch (e) {
      // nada.
    }

    for (final redirect in redirects) {
      await redirect.response?.close();
    }

    if (body?.data is Closeable) {
      await (body.data as Closeable).close();
    }

    await onClose?.call();
  }

  @override
  bool get isClosed => _isClosed;

  @override
  String toString() {
    return 'Response { body: $body, code: $code,'
        ' totalMilliseconds: $totalMilliseconds,'
        ' spentMilliseconds: $spentMilliseconds,'
        ' sentAt: $sentAt, receivedAt: $receivedAt,'
        ' headers: $headers, cookies: $cookies, message: $message,'
        ' request: $request, localPort: $localPort,'
        ' redirects: $redirects, originalRequest: $originalRequest,'
        ' address: $address, cacheControl: $cacheControl,'
        ' networkResponse: $networkResponse, cacheResponse: $cacheResponse }';
  }
}
