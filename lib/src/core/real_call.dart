import 'package:restio/src/core/cache/cache.dart';
import 'package:restio/src/core/call.dart';
import 'package:restio/src/core/cancellable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/exceptions.dart';
import 'package:restio/src/core/interceptor_chain.dart';
import 'package:restio/src/core/internal/bridge_interceptor.dart';
import 'package:restio/src/core/internal/connect_interceptor.dart';
import 'package:restio/src/core/internal/cookie_interceptor.dart';
import 'package:restio/src/core/internal/follow_up_interceptor.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

class RealCall implements Call {
  final Restio client;
  @override
  final Request request;
  final _cancellable = Cancellable();
  var _executed = false;
  var _executing = false;

  RealCall({
    this.client,
    this.request,
  });

  @override
  void cancel(String message) {
    _cancellable.cancel(message);
  }

  @override
  Future<Response> execute() async {
    if (!_executing && !isCancelled) {
      _executing = true;

      try {
        final interceptors = [
          // Interceptors.
          if (client.interceptors != null)
            ...client.interceptors,
          // Redirects.
          FollowUpInterceptor(client),
          // Cookies.
          CookieInterceptor(client.cookieJar),
          BridgeInterceptor(client),
          // Cache.
          CacheInterceptor(client),
          // Network Interceptors.
          if (client.networkInterceptors != null)
            ...client.networkInterceptors,
          // Connection.
          ConnectInterceptor(
            client: client,
            cancellable: _cancellable,
          ),
        ];

        final chain = InterceptorChain(
          call: this,
          request: request,
          interceptors: interceptors,
          index: 0,
        );

        return chain.proceed(request);
      } finally {
        _executed = true;
      }
    } else {
      throw const RestioException('Call has already been executed');
    }
  }

  @override
  bool get isExecuted => _executed;

  @override
  bool get isCancelled => _cancellable.isCancelled;
}
