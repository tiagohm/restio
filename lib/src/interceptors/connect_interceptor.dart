import 'dart:async';

import 'package:meta/meta.dart';
import 'package:restio/src/cancellable.dart';
import 'package:restio/src/chain.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/http2_transport.dart';
import 'package:restio/src/http_transport.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';
import 'package:restio/src/transport.dart';
import 'package:path/path.dart';

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
    final transport = client.isHttp2 == true
        ? _createHttp2Transport(client)
        : _createHttpTransport(client);

    if (cancellable != null && cancellable.isCancelled) {
      throw cancellable.exception;
    }

    cancellable?.whenCancel
        ?.catchError((dynamic e, StackTrace stackTrace) async {
      try {
        await transport.cancel();
      } catch (e) {
        // nada.
      }
    });

    var realRequest = request;

    try {
      final requestUri = request.uri;
      final baseUri = client.baseUri;

      if (baseUri != null && requestUri.scheme.isEmpty) {
        final scheme = baseUri.scheme;
        final userinfo = requestUri.userInfo.isEmpty
            ? baseUri.userInfo
            : requestUri.userInfo;
        final host = requestUri.host.isEmpty ? baseUri.host : requestUri.host;
        final port = requestUri.port == 0 ? baseUri.port : requestUri.port;
        final queryParameters = {
          ...baseUri.queryParametersAll,
          ...requestUri.queryParametersAll,
        };

        realRequest = request.copyWith(
          uri: Uri(
            scheme: scheme,
            host: host,
            path: normalize('${baseUri.path}/${requestUri.path}'),
            port: port,
            queryParameters: queryParameters,
            userInfo: userinfo,
          ).normalizePath(),
        );
      }

      final response = await transport.send(realRequest);

      return response.copyWith(
        request: request,
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
