import 'dart:async';

import 'package:meta/meta.dart';
import 'package:restio/src/core/cancellable.dart';
import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/http/http2_transport.dart';
import 'package:restio/src/core/http/http_transport.dart';
import 'package:restio/src/core/http/transport.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

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

  static Transport _createHttpTransport(Restio client) {
    return HttpTransport(client);
  }

  static Transport _createHttp2Transport(Restio client) {
    return Http2Transport(client);
  }

  Future<Response> _execute(final Request request) async {
    final sentAt = DateTime.now();

    final transport = client.http2 == true
        ? _createHttp2Transport(client)
        : _createHttpTransport(client);

    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    // ignore: unawaited_futures
    cancellable?.whenCancel?.catchError((e, stackTrace) async {
      try {
        await transport.cancel();
      } catch (e) {
        // nada.
      }
    });

    try {     
      final response = await transport.send(request);

      final receivedAt = DateTime.now();

      final spentMilliseconds =
          receivedAt.millisecondsSinceEpoch - sentAt.millisecondsSinceEpoch;

      return response.copyWith(
        request: request,
        sentAt: sentAt,
        receivedAt: receivedAt,
        spentMilliseconds: spentMilliseconds,
        totalMilliseconds: spentMilliseconds,
      );
    } on Exception {
      if (cancellable != null && cancellable.isCancelled) {
        throw cancellable.exception;
      } else {
        rethrow;
      }
    } finally {
      // Encerra a conexão, pois ela não é persistente.
      await transport.close();
    }
  }
}
