import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:restio/src/core/request/header/cache_control.dart';
import 'package:restio/src/core/request/header/headers.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/query/queries_builder.dart';
import 'package:restio/src/core/request/request_body.dart';
import 'package:restio/src/core/request/request_options.dart';
import 'package:restio/src/core/request/request_uri.dart';

class Request extends Equatable {
  final RequestUri uri;
  final String method;
  final Headers headers;
  final RequestBody body;
  final Map<String, dynamic> extra;
  final CacheControl cacheControl;
  final RequestOptions options;

  Request({
    @required RequestUri uri,
    this.method = 'GET',
    Headers headers,
    Queries queries,
    this.body,
    this.extra,
    CacheControl cacheControl,
    RequestOptions options,
  })  : assert(uri != null),
        uri = _obtainUri(uri, queries),
        headers = headers ?? Headers.empty,
        cacheControl = cacheControl ??
            CacheControl.fromHeaders(headers) ??
            CacheControl.empty,
        options = options ?? RequestOptions.empty;

  Request.get(
    String uri, {
    Headers headers,
    Queries queries,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
    RequestOptions options,
  }) : this(
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          extra: extra,
          cacheControl: cacheControl,
          options: options,
        );

  Request.post(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
    RequestOptions options,
  }) : this(
          method: 'POST',
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
          options: options,
        );

  Request.put(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
    RequestOptions options,
  }) : this(
          method: 'PUT',
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
          options: options,
        );

  Request.head(
    String uri, {
    Headers headers,
    Queries queries,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
    RequestOptions options,
  }) : this(
          method: 'HEAD',
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          extra: extra,
          cacheControl: cacheControl,
          options: options,
        );

  Request.delete(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
    RequestOptions options,
  }) : this(
          method: 'DELETE',
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
          options: options,
        );

  Request.patch(
    String uri, {
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
    RequestOptions options,
  }) : this(
          method: 'PATCH',
          uri: RequestUri.parse(uri),
          headers: headers,
          queries: queries,
          body: body,
          extra: extra,
          options: options,
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
    final builder = QueriesBuilder();
    // Adiciona as queries da URL.
    uri.queries.forEach(builder.addItem);
    // Adiciona as queries.
    queries?.forEach(builder.addItem);
    return builder.build();
  }

  Request copyWith({
    RequestUri uri,
    String method,
    Headers headers,
    Queries queries,
    RequestBody body,
    Map<String, dynamic> extra,
    CacheControl cacheControl,
    RequestOptions options,
  }) {
    return Request(
      uri: uri ?? this.uri,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      queries: queries ?? Queries.empty,
      body: body ?? this.body,
      extra: extra ?? this.extra,
      cacheControl: cacheControl ?? this.cacheControl,
      options: options ?? this.options,
    );
  }

  @override
  List<Object> get props => [
        uri,
        method,
        headers,
        queries,
        body,
        extra,
        options,
      ];

  @override
  String toString() {
    return 'Request { uri: $uri, method: $method, headers: $headers,'
        ' body: $body, extra: $extra, cacheControl: $cacheControl }';
  }
}
