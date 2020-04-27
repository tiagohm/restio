import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/common/decompressor.dart';
import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/cache/cache_store.dart';
import 'package:restio/src/core/cache/editor.dart';
import 'package:restio/src/core/cache/snapshot.dart';
import 'package:restio/src/core/cache/snapshotable.dart';
import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/header/headers_builder.dart';
import 'package:restio/src/core/request/header/media_type.dart';
import 'package:restio/src/core/request/http_method.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/response/response_stream.dart';

part 'cache_interceptor.dart';
part 'cache_request.dart';
part 'cache_strategy.dart';
part 'entry.dart';

typedef KeyExtractor = String Function(RequestUri uri);

String _defaultKeyExtractor(RequestUri uri) {
  return HEX.encode(md5.convert(utf8.encode(uri.toUriString())).bytes);
}

class Cache {
  final CacheStore store;
  final KeyExtractor _keyExtractor;

  var _networkCount = 0;
  var _hitCount = 0;
  var _requestCount = 0;

  static const entryMetaData = 0;
  static const entryBody = 1;
  static const entryCount = 2;

  Cache({
    @required this.store,
    KeyExtractor keyExtractor,
  })  : assert(store != null),
        _keyExtractor = keyExtractor ?? _defaultKeyExtractor;

  int get networkCount {
    return _networkCount;
  }

  int get hitCount {
    return _hitCount;
  }

  int get requestCount {
    return _requestCount;
  }

  void _trackConditionalCacheHit() {
    _hitCount++;
  }

  void _trackResponse(CacheStrategy cacheStrategy) {
    _requestCount++;

    if (cacheStrategy.networkRequest != null) {
      // If this is a conditional request, we'll increment hitCount if/when it hits.
      _networkCount++;
    } else if (cacheStrategy.cacheResponse != null) {
      // This response uses the cache and not the network. That's a cache hit.
      _hitCount++;
    }
  }

  String _getKey(Request request) {
    return _keyExtractor(request.uri);
  }

  Future<Response> _get(Request request) async {
    final key = _getKey(request);
    Snapshot snapshot;
    Entry entry;

    try {
      snapshot = await store.get(key);
    } catch (e, stackTrace) {
      // Give up because the cache cannot be read.
      print(e);
      print(stackTrace);
      return null;
    }

    if (snapshot == null) {
      return null;
    }

    try {
      try {
        entry = await Entry.sourceEntry(snapshot.source(entryMetaData));
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        return null;
      }

      final response = entry.response(snapshot);

      if (!entry.matches(request, response)) {
        return null;
      }

      return response;
    } finally {
      await snapshot.close();
    }
  }

  Future<CacheRequest> _put(Response response) async {
    final method = response.request.method;

    if (HttpMethod.invalidatesCache(method)) {
      try {
        await _remove(response.request);
      } catch (e, stackTrace) {
        print(e);
        print(stackTrace);
        // The cache cannot be written.
      }

      return null;
    }

    if (method != HttpMethod.get) {
      // Don't cache non-GET responses. We're technically allowed to cache
      // HEAD requests and some POST requests, but the complexity of doing
      // so is high and the benefit is low.
      return null;
    }

    if (response.headers.hasVaryAll) {
      return null;
    }

    final entry = Entry.fromResponse(response);
    Editor editor;

    try {
      editor = await store.edit(_getKey(response.request));

      if (editor == null) {
        return null;
      }

      final metaData = entry.metaData();

      return CacheRequest(editor, metaData);
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      await _abortQuietly(editor);
      return null;
    }
  }

  Future<void> _update(
    Response cached,
    Response network,
  ) async {
    final entry = Entry.fromResponse(network);
    final body = cached.body as Snapshotable;
    final snapshot = body.snapshot;
    Editor editor;
    Sink<List<int>> sink;

    try {
      editor = await store.edit(snapshot.key, snapshot.sequenceNumber);

      if (editor != null) {
        final metaData = entry.metaData();
        sink = editor.newSink(Cache.entryMetaData);
        sink.add(metaData);

        if (sink is Closeable) {
          await (sink as Closeable).close();
        } else {
          sink.close();
        }

        await editor.commit();
      }
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      await _abortQuietly(editor);
    }
  }

  Future<bool> _remove(Request request) {
    return store.remove(_getKey(request));
  }

  Future<void> clear() {
    return store.clear();
  }

  Future<int> size() {
    return store.size();
  }

  Future<void> _abortQuietly(Editor editor) async {
    try {
      await editor?.abort();
    } catch (e) {
      // nada.
    }
  }
}
