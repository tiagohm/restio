import 'dart:io';

import 'package:restio/src/chain.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/exceptions.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/redirect.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

class FollowUpInterceptor implements Interceptor {
  final Restio client;

  FollowUpInterceptor({
    this.client,
  });

  @override
  Future<Response> intercept(Chain chain) async {
    final originalRequest = chain.request;
    var request = originalRequest;
    var count = 0;
    final redirects = <Redirect>[];

    final startTime = DateTime.now();

    while (true) {
      final sentAt = DateTime.now();
      final response = await chain.proceed(request);

      final elapsedMilliseconds = response.receivedAt.millisecondsSinceEpoch -
          startTime.millisecondsSinceEpoch;
      final spentMilliseconds = response.receivedAt.millisecondsSinceEpoch -
          sentAt.millisecondsSinceEpoch;

      final followUp = await _followUpRequest(response);

      if (followUp == null) {
        return response.copyWith(
          redirects: redirects,
          originalRequest: originalRequest,
          spentMilliseconds: spentMilliseconds,
          totalMilliseconds: elapsedMilliseconds,
          sentAt: sentAt,
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
        elapsedMilliseconds: elapsedMilliseconds,
        response: response.copyWith(
          originalRequest: originalRequest,
          spentMilliseconds: spentMilliseconds,
          totalMilliseconds: spentMilliseconds,
          sentAt: sentAt,
        ),
      ));
    }
  }

  Future<Request> _followUpRequest(Response response) {
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

  Future<Request> _buildRedirectRequest(Response response) {
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
  ) {
    try {
      final retryAfter = response.headers.first(HttpHeaders.retryAfterHeader);
      final seconds = Duration(seconds: int.parse(retryAfter)) ??
          HttpDate.parse(retryAfter).difference(DateTime.now().toUtc());
      return Future.delayed(seconds, () => request);
    } catch (e) {
      return Future(() => request);
    }
  }
}
