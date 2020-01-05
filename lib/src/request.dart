import 'package:meta/meta.dart';
import 'package:restio/src/cache/cache_control.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/queries.dart';
import 'package:restio/src/request_body.dart';

class Request {
  final Uri uri;
  final Uri uriWithQueries;
  final String method;
  final Headers headers;
  final Queries queries;
  final RequestBody body;
  final Map<String, dynamic> extra;
  final CacheControl cacheControl;

  Request({
    @required Uri uri,
    this.method = 'GET',
    Headers headers,
    Queries queries,
    this.body,
    this.extra,
    CacheControl cacheControl,
  })  : assert(uri != null),
        uri = _obtainUriWithoutQueries(uri),
        uriWithQueries = _obtainUriWithQueries(uri, queries),
        headers = headers ?? HeadersBuilder().build(),
        queries = _obtainQueries(uri, queries),
        cacheControl =
            cacheControl ?? CacheControl.from(headers) ?? const CacheControl();

  Request.get(
    String uri, {
    Headers headers,
    Queries queries,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
  }) : this(
          uri: Uri.parse(uri),
          headers: headers,
          queries: queries,
          extra: extra,
          cacheControl: cacheControl,
        );

  Request.post(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
  }) : this(
          method: 'POST',
          uri: Uri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
        );

  Request.put(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
  }) : this(
          method: 'PUT',
          uri: Uri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
        );

  Request.head(
    String uri, {
    Headers headers,
    Queries queries,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
  }) : this(
          method: 'HEAD',
          uri: Uri.parse(uri),
          headers: headers,
          queries: queries,
          extra: extra,
          cacheControl: cacheControl,
        );

  Request.delete(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
  }) : this(
          method: 'DELETE',
          uri: Uri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
        );

  Request.patch(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
  }) : this(
          method: 'PATCH',
          uri: Uri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
        );

  static Uri _obtainUriWithoutQueries(Uri uri) {
    return Uri(
      host: uri.host,
      pathSegments: uri.pathSegments,
      port: uri.port,
      scheme: uri.scheme,
      userInfo: uri.userInfo,
    );
  }

  static Uri _obtainUriWithQueries(
    Uri uri,
    Queries queries,
  ) {
    queries = _obtainQueries(uri, queries);
    uri = _obtainUriWithoutQueries(uri);

    return Uri(
      host: uri.host,
      pathSegments: uri.pathSegments,
      port: uri.port,
      scheme: uri.scheme,
      userInfo: uri.userInfo,
      queryParameters: queries?.isNotEmpty == true ? queries.toMap() : null,
    );
  }

  static Queries _obtainQueries(
    Uri uri,
    Queries queries,
  ) {
    final res = QueriesBuilder();

    // Adiciona as queries da URL.
    uri.queryParametersAll.forEach(res.add);

    // Adiciona as queries.
    queries?.forEach(res.add);

    return res.build();
  }

  Request copyWith({
    Uri uri,
    String method,
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
  }) {
    return Request(
      uri: uri ?? this.uri,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      queries: queries ?? this.queries,
      body: body ?? this.body,
      extra: extra ?? this.extra,
      cacheControl: cacheControl ?? this.cacheControl,
    );
  }

  @override
  String toString() {
    return 'Request { uri: $uri, method: $method, headers: $headers, queries: $queries, body: $body, extra: $extra, cacheControl: $cacheControl }';
  }
}
