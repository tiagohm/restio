import 'dart:async';
import 'dart:io';

import 'package:restio/src/cache/cache_request.dart';
import 'package:restio/src/cache/cache_strategy.dart';
import 'package:restio/src/chain.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/compression_type.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/http_method.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/response.dart';
import 'package:restio/src/response_body.dart';

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

    final cacheCandidate = await cache.get(request);

    final now = DateTime.now();

    final strategy = CacheStrategyFactory(
            now.millisecondsSinceEpoch, request, cacheCandidate)
        .get();
    final networkRequest = strategy.networkRequest;
    final cacheResponse = strategy.cacheResponse;

    cache.trackResponse(strategy);

    if (cacheCandidate != null && cacheResponse == null) {
      // The cache candidate wasn't applicable. Close it.
      await cacheCandidate.body?.close();
    }

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
      return cacheResponse.copyWith(
        cacheResponse: _stripBody(cacheResponse),
      );
    }

    Response networkResponse;

    try {
      networkResponse = await chain.proceed(networkRequest);
    } catch (e) {
      // If we're crashing on I/O or otherwise, don't leak the cache body.
      if (networkResponse == null && cacheCandidate != null) {
        await cacheCandidate.body?.close();
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

        await networkResponse.body?.close();

        // Update the cache after combining headers but before stripping the
        // Content-Encoding header (as performed by initContentStream()).
        cache.trackConditionalCacheHit();

        await cache.update(cacheResponse, response);

        return response;
      } else {
        await cacheResponse.body?.close();
      }
    }

    final response = networkResponse.copyWith(
      cacheResponse: _stripBody(cacheResponse),
      networkResponse: _stripBody(networkResponse),
    );

    if (response.hasBody && response.canCache(networkRequest)) {
      // Offer this request to the cache.
      final cacheRequest = await cache.put(response);
      return _cacheWritingResponse(cacheRequest, response);
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

    return response;
  }

  static ResponseBody _emptyBody() {
    return ResponseBody.bytes(
      const [],
      compressionType: CompressionType.notCompressed,
      contentLength: 0,
      contentType: MediaType.octetStream,
    );
  }

  static Response _stripBody(Response response) {
    return response?.copyWith(body: _emptyBody());
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

    final cacheSink = await cacheRequest.body();

    if (cacheSink == null) {
      return response;
    }

    final cacheStream = StreamTransformer<List<int>, List<int>>.fromHandlers(
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
      },
    ).bind(response.body.data.stream);

    return response.copyWith(
      body: _CacheResponseBody(
        cacheStream,
        () async => cacheSink.close(),
        compressionType: response.body.compressionType,
        contentLength: response.body.contentLength,
        contentType: response.body.contentType,
        onProgress: response.body.onProgress,
      ),
    );
  }
}

class _CacheResponseBody extends ResponseBody {
  final Future Function() onClose;

  _CacheResponseBody(
    Stream<List<int>> stream,
    this.onClose, {
    MediaType contentType,
    int contentLength,
    CompressionType compressionType,
    void Function(int sent, int total, bool done) onProgress,
  }) : super(
          stream,
          contentType: contentType,
          contentLength: contentLength,
          compressionType: compressionType,
          onProgress: onProgress,
        );

  @override
  Future close() => onClose();
}
