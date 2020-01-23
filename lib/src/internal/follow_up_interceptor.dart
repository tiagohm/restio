import 'dart:io';
import 'dart:math';

import 'package:restio/src/chain.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/exceptions.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/redirect.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

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

      final followUp = await _followUpRequest(response);

      if (followUp == null) {
        final totalMilliseconds = response.networkResponse?.totalMilliseconds ??
            response.receivedAt.millisecondsSinceEpoch -
                startTime.millisecondsSinceEpoch;

        return response.copyWith(
          redirects: redirects,
          originalRequest: originalRequest,
          totalMilliseconds: max(0, totalMilliseconds),
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

  Future<Request> _followUpRequest(Response response) async {
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
            : _buildRedirectRequest(response);
      case HttpStatus.multipleChoices:
      case HttpStatus.movedPermanently:
      case HttpStatus.movedTemporarily:
      case HttpStatus.seeOther:
        return _buildRedirectRequest(response);
      default:
        return null;
    }
  }

  Future<Request> _buildRedirectRequest(Response response) async {
    // Does the client allow redirects?
    if (!client.followRedirects) {
      return null;
    }

    final location = response.headers.first(HttpHeaders.locationHeader);

    if (location != null && location.isNotEmpty) {
      final uri = response.request.uri.resolve(location);

      if (uri == null) {
        return null;
      }

      return _retryAfter(response, response.request.copyWith(uri: uri));
    } else {
      return null;
    }
  }

  Future<Request> _retryAfter(
    Response response,
    Request request,
  ) async {
    try {
      final retryAfter = response.headers.first(HttpHeaders.retryAfterHeader);
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
