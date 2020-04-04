import 'package:meta/meta.dart';
import 'package:restio/src/cache/cache_control.dart';
import 'package:restio/src/headers.dart';
import 'package:restio/src/queries.dart';
import 'package:restio/src/request_body.dart';
import 'package:restio/src/request_uri.dart';

class Request {
  final RequestUri uri;
  final String method;
  final Headers headers;
  final RequestBody body;
  final Map<String, dynamic> extra;
  final CacheControl cacheControl;

  Request({
    @required RequestUri uri,
    this.method = 'GET',
    Headers headers,
    Queries queries,
    this.body,
    this.extra,
    CacheControl cacheControl,
  })  : assert(uri != null),
        uri = _obtainUri(uri, queries),
        headers = headers ?? HeadersBuilder().build(),
        cacheControl = cacheControl ??
            CacheControl.fromHeaders(headers) ??
            CacheControl.empty;

  Request.get(
    String uri, {
    Headers headers,
    Queries queries,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
  }) : this(
          uri: RequestUri.parse(uri),
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
          uri: RequestUri.parse(uri),
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
          uri: RequestUri.parse(uri),
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
          uri: RequestUri.parse(uri),
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
          uri: RequestUri.parse(uri),
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
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
        );

  Queries get queries => uri.queries;

  static RequestUri _obtainUri(
    RequestUri uri,
    Queries queries,
  ) {
    queries = _obtainQueries(uri, queries);
    return uri.copyWith(queries: queries);
  }

  static Queries _obtainQueries(
    RequestUri uri,
    Queries queries,
  ) {
    final res = QueriesBuilder();

    // Adiciona as queries da URL.
    uri.queries.forEach(res.add);

    // Adiciona as queries.
    queries?.forEach(res.add);

    return res.build();
  }

  Request copyWith({
    RequestUri uri,
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
