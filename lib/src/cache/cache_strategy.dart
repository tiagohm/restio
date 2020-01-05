import 'dart:io';
import 'dart:math';

import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

class CacheStrategy {
  final Request networkRequest;
  final Response cacheResponse;

  CacheStrategy._(
    this.networkRequest,
    this.cacheResponse,
  );
}

class CacheStrategyFactory {
  final int nowMillis;
  final Request request;
  final Response cacheResponse;

  DateTime _servedDate;
  String _servedDateString;

  DateTime _lastModified;
  String _lastModifiedString;

  DateTime _expires;

  int _sentRequestMillis;
  int _receivedResponseMillis;

  String _etag;

  int _ageSeconds = -1;

  CacheStrategyFactory(
    this.nowMillis,
    this.request,
    this.cacheResponse,
  ) {
    if (cacheResponse != null) {
      _sentRequestMillis = cacheResponse.sentAt.millisecondsSinceEpoch;
      _receivedResponseMillis = cacheResponse.receivedAt.millisecondsSinceEpoch;

      final headers = cacheResponse.headers;

      for (var i = 0; i < headers.length; i++) {
        final name = headers.nameAt(i);
        final value = headers.valueAt(i);

        if (name == HttpHeaders.dateHeader) {
          _servedDate = HttpDate.parse(value);
          _servedDateString = value;
        } else if (name == HttpHeaders.expiresHeader) {
          _expires = HttpDate.parse(value);
        } else if (name == HttpHeaders.lastModifiedHeader) {
          _lastModified = HttpDate.parse(value);
          _lastModifiedString = value;
        } else if (name == HttpHeaders.etagHeader) {
          _etag = value;
        } else if (name == HttpHeaders.ageHeader) {
          _ageSeconds = value != null ? (int.tryParse(value) ?? -1) : -1;
        }
      }
    }
  }

  CacheStrategy get() {
    final candidate = _getCandidate();

    if (candidate.networkRequest != null && request.cacheControl.onlyIfCached) {
      return CacheStrategy._(null, null);
    }

    return candidate;
  }

  CacheStrategy _getCandidate() {
    // No cached response.
    if (cacheResponse == null) {
      return CacheStrategy._(request, null);
    }

    // If this response shouldn't have been stored, it should never be used
    // as a response source. This check should be redundant as long as the
    // persistence store is well-behaved and the rules are constant.
    if (!cacheResponse.isCacheable(request)) {
      return CacheStrategy._(request, null);
    }

    final requestCaching = request.cacheControl;
    if (requestCaching.noCache || _hasConditions(request)) {
      return CacheStrategy._(request, null);
    }

    final responseCaching = cacheResponse.cacheControl;

    final ageMillis = _cacheResponseAge();
    var freshMillis = _computeFreshnessLifetime();

    if (requestCaching.hasMaxAge) {
      freshMillis = min(freshMillis, requestCaching.maxAge.inMilliseconds);
    }

    var minFreshMillis = 0;
    if (requestCaching.hasMinFresh) {
      minFreshMillis = requestCaching.minFresh.inMilliseconds;
    }

    var maxStaleMillis = 0;
    if (!responseCaching.mustRevalidate && requestCaching.hasMaxState) {
      maxStaleMillis = requestCaching.maxStale.inMilliseconds;
    }

    if (!responseCaching.noCache &&
        ageMillis + minFreshMillis < freshMillis + maxStaleMillis) {
      final builder = cacheResponse.headers.toBuilder();

      if (ageMillis + minFreshMillis >= freshMillis) {
        builder.add(
          HttpHeaders.warningHeader,
          '110 HttpURLConnection \"Response is stale\"',
        );
      }

      final oneDayMillis = const Duration(days: 1).inMilliseconds;

      if (ageMillis > oneDayMillis && _isFreshnessLifetimeHeuristic()) {
        builder.add(
          HttpHeaders.warningHeader,
          '113 HttpURLConnection \"Heuristic expiration\"',
        );
      }

      return CacheStrategy._(
        null,
        cacheResponse.copyWith(headers: builder.build()),
      );
    }

    // Find a condition to add to the request. If the condition is satisfied, the response body
    // will not be transmitted.
    String conditionName;
    String conditionValue;

    if (_etag != null) {
      conditionName = HttpHeaders.ifNoneMatchHeader;
      conditionValue = _etag;
    } else if (_lastModified != null) {
      conditionName = HttpHeaders.ifModifiedSinceHeader;
      conditionValue = _lastModifiedString;
    } else if (_servedDate != null) {
      conditionName = HttpHeaders.ifModifiedSinceHeader;
      conditionValue = _servedDateString;
    } else {
      // No condition! Make a regular request.
      return CacheStrategy._(request, null);
    }

    final conditionalRequestHeaders = request.headers.toBuilder();
    conditionalRequestHeaders.add(conditionName, conditionValue);

    final conditionalRequest =
        request.copyWith(headers: conditionalRequestHeaders.build());

    return CacheStrategy._(conditionalRequest, cacheResponse);
  }

  int _computeFreshnessLifetime() {
    final responseCaching = cacheResponse.cacheControl;
    
    if (responseCaching.hasMaxAge) {
      return responseCaching.maxAge.inMilliseconds;
    } else if (_expires != null) {
      final servedMillis = _servedDate != null
          ? _servedDate.millisecondsSinceEpoch
          : _receivedResponseMillis;
      final delta = _expires.millisecondsSinceEpoch - servedMillis;

      return delta > 0 ? delta : 0;
    } else if (_lastModified != null &&
        !cacheResponse.request.uriWithQueries.hasQuery) {
      // As recommended by the HTTP RFC and implemented in Firefox, the
      // max age of a document should be defaulted to 10% of the
      // document's age at the time it was served. Default expiration
      // dates aren't used for URIs containing a query.
      final servedMillis = _servedDate != null
          ? _servedDate.millisecondsSinceEpoch
          : _sentRequestMillis;
      final delta = servedMillis - _lastModified.millisecondsSinceEpoch;

      return delta > 0 ? (delta ~/ 10) : 0;
    }

    return 0;
  }

  int _cacheResponseAge() {
    final apparentReceivedAge = _servedDate != null
        ? max(0, _receivedResponseMillis - _servedDate.millisecondsSinceEpoch)
        : 0;
    final receivedAge = _ageSeconds != -1
        ? max(apparentReceivedAge, _ageSeconds * 1000)
        : apparentReceivedAge;
    final responseDuration = _receivedResponseMillis - _sentRequestMillis;
    final residentDuration = nowMillis - _receivedResponseMillis;

    return receivedAge + responseDuration + residentDuration;
  }

  bool _isFreshnessLifetimeHeuristic() {
    return !cacheResponse.cacheControl.hasMaxAge && _expires == null;
  }

  static bool _hasConditions(Request request) {
    return request.headers.has(HttpHeaders.ifModifiedSinceHeader) ||
        request.headers.has(HttpHeaders.ifNoneMatchHeader);
  }
}
