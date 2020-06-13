part of 'cache.dart';

class CacheInterceptor implements Interceptor {
  final Restio client;

  CacheInterceptor(this.client);

  @override
  Future<Response> intercept(Chain chain) async {
    return await _execute(chain) ?? chain.proceed(chain.request);
  }

  Future<Response> _execute(Chain chain) async {
    final cache = client.cache;

    // Cache is ON?
    if (cache == null || cache.store == null) {
      return null;
    }

    final request = chain.request;

    final cacheCandidate = await cache._get(request);

    final now = DateTime.now();

    final strategy = CacheStrategyFactory(
            now.millisecondsSinceEpoch, request, cacheCandidate)
        .get();
    final networkRequest = strategy.networkRequest;
    final cacheResponse = strategy.cacheResponse;

    cache._trackResponse(strategy);

    if (cacheCandidate != null && cacheResponse == null) {
      // The cache candidate wasn't applicable. Close it.
      await cacheCandidate.close();
    }

    // If we're forbidden from using the network and
    // the cache is insufficient, fail.
    if (networkRequest == null && cacheResponse == null) {
      return Response(
        originalRequest: request,
        request: request,
        code: HttpStatus.gatewayTimeout,
        message: 'Unsatisfiable Request (only-if-cached)',
        body: ResponseBody.empty(),
        sentAt: now,
        receivedAt: now,
      );
    }

    // If we don't need the network, we're done.
    if (networkRequest == null) {
      return cacheResponse.copyWith(
        cacheResponse: _stripBody(cacheResponse),
        spentMilliseconds: 0,
        totalMilliseconds: 0,
      );
    }

    Response networkResponse;

    try {
      networkResponse = await chain.proceed(networkRequest);
    } catch (e) {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        await cacheCandidate.close();
      }

      rethrow;
    }

    // If we have a cache response too, then we're doing a conditional get.
    if (cacheResponse != null) {
      if (networkResponse.code == HttpStatus.notModified) {
        final response = cacheResponse.copyWith(
          headers: _combine(cacheResponse.headers, networkResponse.headers),
          sentAt: networkResponse.sentAt,
          receivedAt: networkResponse.receivedAt,
          spentMilliseconds: networkResponse.spentMilliseconds,
          totalMilliseconds: networkResponse.totalMilliseconds,
          cacheResponse: _stripBody(cacheResponse),
          networkResponse: _stripBody(networkResponse),
        );

        await networkResponse.close();

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        cache._trackConditionalCacheHit();

        await cache._update(cacheResponse, response);

        return response;
      } else {
        await cacheResponse.close();
      }
    }

    final response = networkResponse.copyWith(
      cacheResponse: _stripBody(cacheResponse),
      networkResponse: _stripBody(networkResponse),
    );

    if (response.hasBody && response.canCache(networkRequest)) {
      // Offer this request to the cache.
      final cacheRequest = await cache._put(response);
      return _cacheWritingResponse(cacheRequest, response);
    }

    if (HttpMethod.invalidatesCache(networkRequest.method)) {
      try {
        await cache._remove(networkRequest);
      } catch (e) {
        // The cache cannot be written.
      }
    }

    return response;
  }

  static Response _stripBody(Response response) {
    return response?.copyWith(body: ResponseBody.empty());
  }

  static Headers _combine(
    Headers cachedHeaders,
    Headers networkHeaders,
  ) {
    final builder = HeadersBuilder();

    for (var i = 0; i < cachedHeaders.length; i++) {
      final name = cachedHeaders.nameAt(i).toLowerCase();
      final value = cachedHeaders.valueAt(i);

      if (name == HttpHeaders.warningHeader && value.startsWith('1')) {
        continue;
      }

      if (_isContentSpecificHeader(name) ||
          !_isEndToEnd(name) ||
          networkHeaders.value(name) == null) {
        builder.set(cachedHeaders.nameAt(i), value);
      }
    }

    for (var i = 0; i < networkHeaders.length; i++) {
      final name = networkHeaders.nameAt(i).toLowerCase();

      if (!_isContentSpecificHeader(name) && _isEndToEnd(name)) {
        builder.set(networkHeaders.nameAt(i), networkHeaders.valueAt(i));
      }
    }

    return builder.build();
  }

  static bool _isContentSpecificHeader(String name) {
    return name == HttpHeaders.contentLengthHeader ||
        name == HttpHeaders.contentEncodingHeader ||
        name == HttpHeaders.contentTypeHeader;
  }

  static bool _isEndToEnd(String name) {
    return name != HttpHeaders.connectionHeader &&
        name != 'keep-alive' &&
        name != HttpHeaders.proxyAuthenticateHeader &&
        name != HttpHeaders.proxyAuthorizationHeader &&
        name != HttpHeaders.teHeader &&
        name != HttpHeaders.trailerHeader &&
        name != HttpHeaders.transferEncodingHeader &&
        name != HttpHeaders.upgradeHeader;
  }

  Future<Response> _cacheWritingResponse(
    CacheRequest cacheRequest,
    Response response,
  ) async {
    if (cacheRequest == null) {
      return response;
    }

    final cacheSink = await cacheRequest.body();

    if (cacheSink == null) {
      return response;
    }

    final cacheStream = ResponseStream(
      response.body.data,
      onData: cacheSink.add,
      onError: (e, stackTrace) async {
        cacheSink.addError(e, stackTrace);
      },
      onClose: () async {
        await cacheSink.close();
      },
    );

    return response.copyWith(
      body: ResponseBody(
        cacheStream,
        contentLength: response.body.contentLength,
        contentType: response.body.contentType,
      ),
    );
  }
}
