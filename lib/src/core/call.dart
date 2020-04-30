part of 'client.dart';

class _Call implements Call {
  final Restio client;
  @override
  final Request request;
  final _cancellable = Cancellable();
  var _executed = false;
  var _executing = false;

  _Call({
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
