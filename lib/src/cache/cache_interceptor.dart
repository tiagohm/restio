import 'dart:async';
import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/src/cache/cache_request.dart';
import 'package:restio/src/cache/cache_strategy.dart';
import 'package:restio/src/chain.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/response.dart';

class CacheInterceptor implements Interceptor {
  final Restio client;

  CacheInterceptor(this.client);

  @override
  Future<Response> intercept(Chain chain) async {
    return await _execute(chain) ?? chain.proceed(chain.request);
  }

  // https://medium.com/@I_Love_Coding/how-does-okhttp-cache-works-851d37dd29cd
  Future<Response> _execute(Chain chain) async {
    final cache = client.cache;

    // Cache is ON?
    if (cache == null || cache.store == null) {
      return null;
    }

    final request = chain.request;

    final cacheCandidate = await cache.get(request);

    final now = DateTime.now();

    final strategy = CacheStrategyFactory(
            now.millisecondsSinceEpoch, request, cacheCandidate)
        .get();
    final networkRequest = strategy.networkRequest;
    final cacheResponse = strategy.cacheResponse;

    cache.trackResponse(strategy);

    // If we're forbidden from using the network and the cache is insufficient, fail.
    if (networkRequest == null && cacheResponse == null) {
      return Response(
        originalRequest: request,
        request: request,
        code: HttpStatus.gatewayTimeout,
        message: 'Unsatisfiable Request (only-if-cached)',
        body: _emptyBody(),
        sentAt: now,
        spentMilliseconds: 0,
        totalMilliseconds: 0,
        receivedAt: now,
      );
    }

    // If we don't need the network, we're done.
    if (networkRequest == null) {
      return cacheResponse.copyWith(body: _emptyBody());
    }

    final networkResponse = await chain.proceed(networkRequest);

    // If we have a cache response too, then we're doing a conditional get.
    if (cacheResponse != null) {
      if (networkResponse.code == HttpStatus.notModified) {
        final response = cacheResponse.copyWith(
          headers: _combine(cacheResponse.headers, networkResponse.headers),
          sentAt: networkResponse.sentAt,
          receivedAt: networkResponse.receivedAt,
        );

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        cache.trackConditionalCacheHit();

        await cache.update(cacheResponse, response);

        return response;
      }
    }

    if (networkResponse.hasBody &&
        networkResponse.isCacheable(networkRequest)) {
      // Offer this request to the cache.
      final cacheRequest = await cache.put(networkResponse);
      return _cacheWritingResponse(cacheRequest, networkResponse);
    }

    if (HttpMethod.invalidatesCache(networkRequest.method)) {
      try {
        await cache.remove(networkRequest);
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        // The cache cannot be written.
      }
    }

    return networkResponse;
  }

  ResponseBody _emptyBody() {
    return ResponseBody.bytes(
      const [],
      compressionType: CompressionType.notCompressed,
      contentLength: 0,
      contentType: MediaType.octetStream,
      onProgress: client.onDownloadProgress,
    );
  }

  static Headers _combine(
    Headers cachedHeaders,
    Headers networkHeaders,
  ) {
    final result = HeadersBuilder();

    for (var i = 0; i < cachedHeaders.length; i++) {
      final name = cachedHeaders.nameAt(i);
      final value = cachedHeaders.valueAt(i);

      if (name == HttpHeaders.warningHeader && value.startsWith('1')) {
        continue;
      }

      if (_isContentSpecificHeader(name) ||
          !_isEndToEnd(name) ||
          networkHeaders.value(name) == null) {
        result.add(name, value);
      }
    }

    for (var i = 0; i < networkHeaders.length; i++) {
      final name = networkHeaders.nameAt(i);
      if (!_isContentSpecificHeader(name) && _isEndToEnd(name)) {
        result.add(name, networkHeaders.valueAt(i));
      }
    }

    return result.build();
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

    final cacheSink = cacheRequest.body();

    if (cacheSink == null) {
      return response;
    }

    final cacheWritingSource =
        StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        sink.add(data);
        cacheSink.add(data);
      },
      handleError: (error, stackTrace, sink) {
        sink.addError(error, stackTrace);
        cacheSink.addError(error, stackTrace);
      },
      handleDone: (sink) {
        sink.close();
        cacheSink.close();
      },
    ).bind(response.body.data.stream);

    return response.copyWith(
      body: ResponseBody.stream(
        cacheWritingSource,
        compressionType: response.body.compressionType,
        contentLength: response.body.contentLength,
        contentType: response.body.contentType,
        onProgress: response.body.onProgress,
      ),
    );
  }
}
