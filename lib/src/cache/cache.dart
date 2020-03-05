import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hex/hex.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/cache/cache_request.dart';
import 'package:restio/src/cache/cache_store.dart';
import 'package:restio/src/cache/cache_strategy.dart';
import 'package:restio/src/cache/editor.dart';
import 'package:restio/src/cache/entry.dart';
import 'package:restio/src/cache/snapshot.dart';
import 'package:restio/src/cache/snapshotable.dart';
import 'package:restio/src/helpers.dart';
import 'package:restio/src/http_method.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/request_uri.dart';
import 'package:restio/src/response.dart';

export 'cache_control.dart';
export 'cache_store.dart';
export 'disk_cache_store.dart';
export 'editor.dart';
export 'memory_cache_store.dart';
export 'snapshot.dart';
export 'snapshotable.dart';

typedef KeyExtractor = String Function(RequestUri uri);

String _defaultKeyExtractor(RequestUri uri) {
  return HEX.encode(md5.convert(utf8.encode(uri.toString())).bytes);
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

  void trackConditionalCacheHit() {
    _hitCount++;
  }

  void trackResponse(CacheStrategy cacheStrategy) {
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

  Future<Response> get(Request request) async {
    final key = _getKey(request);
    Snapshot snapshot;
    Entry entry;

    try {
      snapshot = await store.get(key);

      if (snapshot == null) {
        return null;
      }
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      // Give up because the cache cannot be read.
      return null;
    }

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

    return response.copyWith(
      cookies: obtainCookiesFromResponse(response),
    );
  }

  Future<CacheRequest> put(Response response) async {
    final method = response.request.method;

    if (HttpMethod.invalidatesCache(method)) {
      try {
        await remove(response.request);
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

  Future<void> update(
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
        await editor.commit();
      }
    } catch (e, stackTrace) {
      print(e);
      print(stackTrace);
      await _abortQuietly(editor);
    } finally {
      sink.close();
    }
  }

  Future<bool> remove(Request request) {
    return store.remove(_getKey(request));
  }

  Future<bool> clear() {
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
