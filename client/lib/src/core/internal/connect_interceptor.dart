import 'dart:async';

import 'package:meta/meta.dart';
import 'package:restio/src/core/call/cancellable.dart';
import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/transport/http2_transport.dart';
import 'package:restio/src/core/transport/http_transport.dart';

class ConnectInterceptor implements Interceptor {
  final Restio client;
  final Cancellable cancellable;

  ConnectInterceptor({
    @required this.client,
    this.cancellable,
  }) : assert(client != null);

  @override
  Future<Response> intercept(Chain chain) async {
    return _execute(chain.request);
  }

  Future<Response> _execute(final Request request) async {
    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    final transport =
        request.options.http2 ? Http2Transport(client) : HttpTransport(client);

    void cancelTransport(String message) async {
      try {
        await transport.cancel(message);
      } catch (e) {
        // nada.
      }
    }

    cancellable?.add(cancelTransport);

    try {
      final sentAt = DateTime.now();
      final response = await transport.send(request, cancellable: cancellable);
      final receivedAt = DateTime.now();

      if (cancellable != null && cancellable.isCancelled) {
        await response?.close();
        throw cancellable.exception;
      }

      final spentMilliseconds =
          receivedAt.millisecondsSinceEpoch - sentAt.millisecondsSinceEpoch;

      return response.copyWith(
        request: request,
        sentAt: sentAt,
        receivedAt: receivedAt,
        spentMilliseconds: spentMilliseconds,
        totalMilliseconds: spentMilliseconds,
      );
    } finally {
      cancellable?.remove(cancelTransport);
    }
  }
}
