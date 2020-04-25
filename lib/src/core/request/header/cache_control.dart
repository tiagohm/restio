import 'dart:io';

import 'package:string_scanner/string_scanner.dart';

import '../../../common/item.dart';
import 'headers.dart';

class CacheControl extends Item {
  final bool noCache;
  final bool noStore;
  final Duration maxAge;
  final Duration maxStale;
  final Duration minFresh;
  final bool isPrivate;
  final bool isPublic;
  final bool noTransform;
  final bool immutable;
  final bool mustRevalidate;
  final bool onlyIfCached;

  const CacheControl({
    this.noCache = false,
    this.noStore = false,
    this.maxAge,
    this.isPrivate = false,
    this.isPublic = false,
    this.noTransform = false,
    this.immutable = false,
    this.mustRevalidate = false,
    this.onlyIfCached = false,
    this.maxStale,
    this.minFresh,
  });

  static const empty = CacheControl();

  static const forceNetwork = CacheControl(noCache: true);

  static const forceCache = CacheControl(
    onlyIfCached: true,
    maxStale: Duration(seconds: 9223372036854),
  );

  @override
  String get name => HttpHeaders.cacheControlHeader;

  @override
  String get value => toString();

  factory CacheControl.fromMap(Map<String, String> params) {
    if (params == null) {
      return null;
    }

    return CacheControl(
      noStore: params.containsKey('no-store'),
      noCache: params.containsKey('no-cache'),
      maxAge: params['max-age'] != null
          ? Duration(seconds: int.parse(params['max-age']))
          : null,
      immutable: params.containsKey('immutable'),
      noTransform: params.containsKey('no-transform'),
      isPrivate: params.containsKey('private'),
      isPublic: params.containsKey('public'),
      mustRevalidate: params.containsKey('must-revalidate'),
      onlyIfCached: params.containsKey('only-if-cached'),
      maxStale: params.containsKey('max-stale') &&
              params['max-stale'] != null &&
              params['max-stale'].isNotEmpty
          ? Duration(seconds: int.parse(params['max-stale']))
          : params.containsKey('max-stale')
              ? const Duration(seconds: 9223372036854)
              : null,
      minFresh: params['min-fresh'] != null
          ? Duration(seconds: int.parse(params['min-fresh']))
          : null,
    );
  }

  factory CacheControl.parse(String text) {
    text = text?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return CacheControl.fromMap(_parseHeader(text));
  }

  factory CacheControl.fromHeaders(Headers headers) {
    if (headers == null) {
      return null;
    }

    final params = <String, String>{};
    final pragma = headers.all(HttpHeaders.pragmaHeader);
    final cacheControl = headers.all(HttpHeaders.cacheControlHeader);

    for (final item in pragma) {
      if (item.isNotEmpty) {
        params.addAll(_parseHeader(item.value));
      }
    }

    for (final item in cacheControl) {
      if (item.isNotEmpty) {
        params.addAll(_parseHeader(item.value));
      }
    }

    if (params.isEmpty) {
      return CacheControl.empty;
    }

    return CacheControl.fromMap(params);
  }

  bool get hasMaxAge {
    return maxAge != null && !maxAge.isNegative;
  }

  bool get hasMaxStale {
    return maxStale != null && !maxStale.isNegative;
  }

  bool get hasMinFresh {
    return minFresh != null && !minFresh.isNegative;
  }

  static final _whitespace = RegExp(r'[ \t]*');
  static final _token = RegExp(r'[^()<>@,;:"\\/[\]?={} \t\x00-\x1F\x7F]+');
  static final _quotedString = RegExp(r'"(?:[^"\x00-\x1F\x7F]|\\.)*"');
  static final _quotedPair = RegExp(r'\\(.)');

  static Map<String, String> _parseHeader(String text) {
    final scanner = StringScanner(text);
    final params = <String, String>{};
    _parseList(scanner, () => _scanParam(scanner, params));
    return params;
  }

  static void _scanParam(
    StringScanner scanner,
    Map<String, String> params,
  ) {
    String name, value;

    // ex.: no-cache
    scanner
      ..scan(_whitespace)
      ..expect(_token, name: 'name');
    name = scanner.lastMatch[0].toLowerCase();
    scanner.scan(_whitespace);

    if (scanner.isDone || scanner.matches(',')) {
      params[name] = null;
      return;
    }

    // ex.: max-age=123456789 ou max-age='123456789'
    if (scanner.scan('=')) {
      scanner.scan(_whitespace);
      if (scanner.scan(_token)) {
        value = scanner.lastMatch[0];
      } else {
        value = _expectQuotedString(
          scanner,
          name: 'quoted string',
        );
      }
      scanner.scan(_whitespace);
    }

    params[name] = value;
  }

  static String _expectQuotedString(
    StringScanner scanner, {
    String name,
  }) {
    scanner.expect(_quotedString, name: name);
    final string = scanner.lastMatch[0];
    return string
        .substring(1, string.length - 1)
        .replaceAllMapped(_quotedPair, (match) => match[1]);
  }

  static void _parseList(
    StringScanner scanner,
    void Function() parseElement,
  ) {
    // Consume initial empty values.
    while (scanner.scan(',')) {
      scanner.scan(_whitespace);
    }

    parseElement();
    scanner.scan(_whitespace);

    while (scanner.scan(',')) {
      scanner.scan(_whitespace);

      // Empty elements are allowed, but excluded from the results.
      if (scanner.matches(',') || scanner.isDone) {
        continue;
      }

      parseElement();
      scanner.scan(_whitespace);
    }
  }

  CacheControl copyWith({
    bool noCache,
    bool noStore,
    Duration maxAge,
    bool isPrivate,
    bool isPublic,
    bool noTransform,
    bool immutable,
    bool mustRevalidate,
    bool onlyIfCached,
  }) {
    return CacheControl(
      noCache: noCache ?? this.noCache,
      noStore: noStore ?? this.noStore,
      maxAge: maxAge ?? this.maxAge,
      isPrivate: isPrivate ?? this.isPrivate,
      isPublic: isPublic ?? this.isPublic,
      noTransform: noTransform ?? this.noTransform,
      immutable: immutable ?? this.immutable,
      mustRevalidate: mustRevalidate ?? this.mustRevalidate,
      onlyIfCached: onlyIfCached ?? this.onlyIfCached,
    );
  }

  String toHeaderString() {
    final sb = StringBuffer();

    if (noCache) {
      sb.write('no-cache, ');
    }

    if (noStore) {
      sb.write('no-store, ');
    }

    if (maxAge != null) {
      sb..write('max-age=')..write(maxAge.inSeconds)..write(', ');
    }

    if (maxStale != null) {
      sb..write('max-stale=')..write(maxStale.inSeconds)..write(', ');
    }

    if (minFresh != null) {
      sb..write('min-fresh=')..write(minFresh.inSeconds)..write(', ');
    }

    if (isPrivate) {
      sb.write('private, ');
    }

    if (isPublic) {
      sb.write('public, ');
    }

    if (noTransform) {
      sb.write('no-transform, ');
    }

    if (immutable) {
      sb.write('immutable, ');
    }

    if (mustRevalidate) {
      sb.write('must-revalidate, ');
    }

    if (onlyIfCached) {
      sb.write('only-if-cached, ');
    }

    return sb.toString();
  }

  @override
  String toString() {
    return 'CacheControl { noCache: $noCache, noStore: $noStore, maxAge: $maxAge, '
        ' maxStale: $maxStale, minFresh: $minFresh, isPrivate: $isPrivate, isPublic: $isPublic, '
        ' noTransform: $noTransform, immutable: $immutable, mustRevalidate: $mustRevalidate, '
        ' onlyIfCached: $onlyIfCached }';
  }

  @override
  List<Object> get props => [
        noCache,
        noStore,
        maxAge,
        maxStale,
        minFresh,
        isPrivate,
        isPublic,
        noTransform,
        immutable,
        mustRevalidate,
        onlyIfCached,
      ];
}
