import 'dart:io';
import 'dart:math';

import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/redirect/redirect.dart';
import 'package:restio/src/core/request/http_method.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_options.dart';
import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/response.dart';

class FollowUpInterceptor implements Interceptor {
  final Restio client;

  FollowUpInterceptor(this.client);

  @override
  Future<Response> intercept(Chain chain) async {
    final originalRequest = chain.request;
    final redirects = <Redirect>[];
    final startTime = DateTime.now();
    final options = mergeOptions(client, originalRequest);
    var request = originalRequest;
    var count = 0;

    while (true) {
      request = request.copyWith(options: options);

      final response = await chain.proceed(request);

      final elapsedMilliseconds = response.receivedAt.millisecondsSinceEpoch -
          startTime.millisecondsSinceEpoch;

      final followUp = await _followUpRequest(response, redirects, options);

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

      if (options.maxRedirects >= 0 && ++count > options.maxRedirects) {
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
    RequestOptions options,
  ) async {
    switch (response.code) {
      case HttpStatus.proxyAuthenticationRequired:
        return options.proxy?.auth?.authenticate(response);
      case HttpStatus.unauthorized:
        return options.auth?.authenticate(response);
      case HttpStatus.permanentRedirect:
      case HttpStatus.temporaryRedirect:
      case HttpStatus.multipleChoices:
      case HttpStatus.movedPermanently:
      case HttpStatus.movedTemporarily:
      case HttpStatus.seeOther:
        return _buildRedirectRequest(response, redirects, options);
      default:
        return null;
    }
  }

  Future<Request> _buildRedirectRequest(
    Response response,
    List<Redirect> redirects,
    RequestOptions options,
  ) async {
    final method = response.request.method;
    final code = response.code;

    // Does the client allow redirects?
    if (!options.followRedirects) {
      return null;
    }

    // Location.
    final location = response.headers.value(HttpHeaders.locationHeader);

    var request = response.request;

    if (location != null && location.isNotEmpty) {
      final uri = request.uri.toUri().resolve(location);

      if (uri == null) {
        return null;
      }

      final sameScheme = uri.scheme == request.uri.scheme;

      // If configured, don't follow redirects between SSL and non-SSL.
      if (!sameScheme && !options.followSslRedirects) {
        return null;
      }

      final requestUri = RequestUri.fromUri(uri);

      // Most redirects don't include a request body.
      if (HttpMethod.permitsRequestBody(method)) {
        final maintainBody = HttpMethod.redirectsWithBody(method) ||
            code == HttpStatus.permanentRedirect ||
            code == HttpStatus.temporaryRedirect;

        if (HttpMethod.redirectsToGet(method) &&
            code != HttpStatus.permanentRedirect &&
            code != HttpStatus.temporaryRedirect) {
          request = request.copyWith(method: 'GET');
        }

        if (!maintainBody) {
          final builder = request.headers.toBuilder();
          builder.removeAll('Transfer-Encoding');
          builder.removeAll('Content-Length');
          builder.removeAll('Content-Type');
          request = request.copyWith(headers: builder.build());
        }

        if (!response.request.uri.canReuseConnectionFor(requestUri)) {
          final builder = request.headers.toBuilder();
          builder.removeAll('Authorization');
          request = request.copyWith(headers: builder.build());
        }
      }

      request = request.copyWith(uri: requestUri, queries: Queries.empty);

      // Redirect Policy.
      if (client.redirectPolicies != null) {
        for (final redirectPolicy in client.redirectPolicies) {
          if (!redirectPolicy.apply(response, request, redirects)) {
            return null;
          }
        }
      }
    }

    // Retry-After Header.
    return await _retryAfter(response, request);
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
