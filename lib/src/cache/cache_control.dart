import 'package:string_scanner/string_scanner.dart';

// https://developer.mozilla.org/pt-BR/docs/Web/HTTP/Headers/Cache-Control
class CacheControl {
  /// In a response, this field's name "no-cache" is misleading. It doesn't prevent us from caching
  /// the response; it only means we have to validate the response with the origin server before
  /// returning it. We can do this with a conditional GET.
  /// In a request, it means do not use a cache to satisfy the request.
  final bool noCache;

  /// If true, this response should not be cached.
  final bool noStore;

  /// The duration past the response's served date that it can be served without validation.
  final Duration maxAgeSeconds;
  final bool isPrivate;
  final bool isPublic;
  final bool noTransform;
  final bool immutable;
  final bool mustRevalidate;

  const CacheControl({
    this.noCache = false,
    this.noStore = false,
    this.maxAgeSeconds,
    this.isPrivate = false,
    this.isPublic = false,
    this.noTransform = false,
    this.immutable = false,
    this.mustRevalidate = false,
  });

  factory CacheControl.parse(String text) {
    text = text?.trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    final params = _parseHeader(text);

    return CacheControl(
      noStore: params.containsKey('no-store'),
      noCache: params.containsKey('no-cache'),
      maxAgeSeconds: params['max-age'] != null
          ? Duration(seconds: int.parse(params['max-age']))
          : null,
      immutable: params.containsKey('immutable'),
      noTransform: params.containsKey('no-transform'),
      isPrivate: params.containsKey('private'),
      isPublic: params.containsKey('public'),
      mustRevalidate: params.containsKey('must-revalidate'),
    );
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

  static void _scanParam(StringScanner scanner, Map<String, String> params) {
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
      if (scanner.matches(',') || scanner.isDone) continue;

      parseElement();
      scanner.scan(_whitespace);
    }
  }

  CacheControl copyWith({
    bool noCache,
    bool noStore,
    Duration maxAgeSeconds,
    bool isPrivate,
    bool isPublic,
    bool noTransform,
    bool immutable,
    bool mustRevalidate,
  }) {
    return CacheControl(
      noCache: noCache ?? this.noCache,
      noStore: noStore ?? this.noStore,
      maxAgeSeconds: maxAgeSeconds ?? this.maxAgeSeconds,
      isPrivate: isPrivate ?? this.isPrivate,
      isPublic: isPublic ?? this.isPublic,
      noTransform: noTransform ?? this.noTransform,
      immutable: immutable ?? this.immutable,
      mustRevalidate: mustRevalidate ?? this.mustRevalidate,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer();
    if (noCache) sb.write('no-cache, ');
    if (noStore) sb.write('no-store, ');
    if (maxAgeSeconds != null) {
      sb..write('max-age=')..write(maxAgeSeconds)..write(', ');
    }
    if (isPrivate) sb.write('private, ');
    if (isPublic) sb.write('public, ');
    if (noTransform) sb.write('no-transform, ');
    if (immutable) sb.write('immutable, ');
    return sb.toString();
  }
}
