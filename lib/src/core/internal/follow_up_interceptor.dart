import 'dart:io';
import 'dart:math';

import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/redirect/redirect.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/response.dart';

class FollowUpInterceptor implements Interceptor {
  final Restio client;

  FollowUpInterceptor(this.client);

  @override
  Future<Response> intercept(Chain chain) async {
    final originalRequest = chain.request;
    var request = originalRequest;
    var count = 0;
    final redirects = <Redirect>[];

    final startTime = DateTime.now();

    while (true) {
      final response = await chain.proceed(request);

      final elapsedMilliseconds = response.receivedAt.millisecondsSinceEpoch -
          startTime.millisecondsSinceEpoch;

      final followUp = await _followUpRequest(response, redirects);

      if (followUp == null) {
        final totalMilliseconds = max(
            response.networkResponse?.totalMilliseconds ?? 0,
            response.receivedAt.millisecondsSinceEpoch -
                startTime.millisecondsSinceEpoch);

        return response.copyWith(
          redirects: redirects,
          originalRequest: originalRequest,
          totalMilliseconds: totalMilliseconds,
        );
      }

      if (client.maxRedirects >= 0 && ++count > client.maxRedirects) {
        throw TooManyRedirectsException(
          'Too many redirects: $count',
          originalRequest.uri,
        );
      }

      request = followUp;

      redirects.add(Redirect(
        request: request,
        elapsedMilliseconds: max(elapsedMilliseconds, 0),
        response: response.copyWith(
          originalRequest: originalRequest,
          totalMilliseconds: response.spentMilliseconds ?? 0,
        ),
      ));
    }
  }

  Future<Request> _followUpRequest(
    Response response,
    List<Redirect> redirects,
  ) async {
    final method = response.request.method;

    switch (response.code) {
      case HttpStatus.proxyAuthenticationRequired:
        return client.proxy?.auth?.authenticate(response);
      case HttpStatus.unauthorized:
        return client.auth?.authenticate(response);
      case HttpStatus.permanentRedirect:
      case HttpStatus.temporaryRedirect:
        return method != 'GET' && method != 'HEAD'
            ? null
            : _buildRedirectRequest(response, redirects);
      case HttpStatus.multipleChoices:
      case HttpStatus.movedPermanently:
      case HttpStatus.movedTemporarily:
      case HttpStatus.seeOther:
        return _buildRedirectRequest(response, redirects);
      default:
        return null;
    }
  }

  Future<Request> _buildRedirectRequest(
    Response response,
    List<Redirect> redirects,
  ) async {
    // Does the client allow redirects?
    if (!client.followRedirects) {
      return null;
    }

    // Location.
    final location = response.headers.value(HttpHeaders.locationHeader);

    Request request;

    if (location != null && location.isNotEmpty) {
      final uri = response.request.uri.toUri().resolve(location);

      if (uri == null) {
        return null;
      }

      // Retry-After Header.
      request = await _retryAfter(
          response,
          response.request.copyWith(
            uri: RequestUri.fromUri(uri),
            queries: Queries.empty,
          ));
    }

    // Redirect Policy.
    if (request != null && client.redirectPolicies != null) {
      for (final redirectPolicy in client.redirectPolicies) {
        if (!redirectPolicy.apply(response, request, redirects)) {
          return null;
        }
      }
    }

    return request;
  }

  Future<Request> _retryAfter(
    Response response,
    Request request,
  ) async {
    try {
      final retryAfter = response.headers.value(HttpHeaders.retryAfterHeader);
      final seconds = int.tryParse(retryAfter);
      final duration = seconds != null
          ? Duration(seconds: seconds)
          : HttpDate.parse(retryAfter).difference(DateTime.now().toUtc());
      return Future.delayed(duration, () => request);
    } catch (e) {
      return request;
    }
  }
}
