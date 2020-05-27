part of 'client.dart';

class _Call implements Call {
  final Restio client;
  @override
  final Request request;
  Cancellable _cancellable;
  var _executing = false;

  _Call({
    this.client,
    this.request,
  });

  @override
  void cancel(String message) {
    _cancellable?.cancel(message);
  }

  @override
  Future<Response> execute() async {
    if (_executing) {
      throw const RestioException('Call is in progress');
    }

    _executing = true;
    _cancellable = Cancellable();

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

      final response = await chain.proceed(request);

      return response;
    } catch (e) {
      if (_cancellable.isCancelled) {
        throw _cancellable.exception;
      } else {
        rethrow;
      }
    } finally {
      _executing = false;
      await _cancellable.close();
    }
  }

  @override
  bool get isExecuting => _executing;

  @override
  bool get isCancelled => _cancellable != null && _cancellable.isCancelled;
}
