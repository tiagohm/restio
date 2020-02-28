import 'package:equatable/equatable.dart';

class RequestUri extends Equatable {
  final String fragment;
  final String host;
  final List<String> path;
  final String port;
  final List<String> query;
  final String scheme;
  final String username;
  final String password;

  const RequestUri({
    this.fragment,
    this.host,
    this.path,
    this.port,
    this.query,
    this.scheme,
    this.username,
    this.password,
  });

  factory RequestUri.fromUri(Uri uri) {
    final userInfo = uri.userInfo?.split(':');

    return RequestUri(
      fragment: uri.fragment,
      host: uri.host,
      path: uri.pathSegments,
      port: uri.port?.toString(),
      scheme: uri.scheme,
      username: userInfo?.isNotEmpty == true ? userInfo[0] : null,
      password: userInfo?.length == 2 ? userInfo[1] : null,
      query: _obtainQueryFromMap(uri.queryParametersAll),
    );
  }

  static List<String> _obtainQueryFromMap(
    Map<String, List<String>> queries,
  ) {
    final res = <String>[];

    queries.forEach((key, values) {
      for (final item in values) {
        res.add(key);
        res.add(item);
      }
    });

    return res;
  }

  factory RequestUri.parse(String uri) {
    final p = parseUri(uri);

    return RequestUri(
      fragment: p['fragment'],
      host: p['host'],
      path: p['path'],
      port: p['port'],
      scheme: p['scheme'],
      username: p['username'],
      password: p['password'],
      query: p['query'],
    );
  }

  @override
  String toString() {
    final sb = StringBuffer();

    sb.write(scheme);
    sb.write(':');

    if (host != null) {
      sb.write('//');

      if (username != null || password != null) {
        if (username != null) {
          sb.write(username);
        }

        if (password != null) {
          sb.write(':');
          sb.write(password);
        }

        sb.write('@');
      }

      sb.write(host);

      if (port != null) {
        sb.write(':');
        sb.write(port);
      }
    }

    if (path != null) {
      for (final item in path) {
        sb.write('/');
        sb.write(item);
      }
    }

    if (query != null && query.isNotEmpty) {
      sb.write('?');

      for (var i = 0; i < query.length; i += 2) {
        if (i > 0) {
          sb.write('&');
        }

        sb.write(query[i]);
        sb.write('=');
        sb.write(query[i + 1]);
      }
    }

    if (fragment != null) {
      sb.write('#');
      sb.write(fragment);
    }

    return sb.toString();
  }

  @override
  List<Object> get props => [
        fragment,
        host,
        path,
        port,
        query,
        scheme,
        username,
        password,
      ];
}

final _schemeRegex = RegExp(r'^([^:]*):');
final _authorityRegex = RegExp(
    r'^//(?:(?<userinfo>.*)@)?(?<host>(?:(?!\[)[^:]+)|\[.*\])(?::(?<port>[^/?#]*))?');
final _pathRegex = RegExp(r'^([^?#]*)');
final _queryRegex = RegExp(r'^\?([^#]*)');
final _fragmentRegex = RegExp(r'^#(.*)');

// TODO: Parse Encoded URI.
Map<String, dynamic> parseUri(String uri) {
  final res = <String, dynamic>{};

  // Scheme.
  var m = _schemeRegex.firstMatch(uri);

  if (m != null) {
    final scheme = m.group(1);
    uri = uri.substring(m.end);
    res['scheme'] = scheme;
  } else {
    throw const MalformedUriException('Invalid scheme');
  }

  // Authority.
  m = _authorityRegex.firstMatch(uri);

  if (m != null) {
    final userInfo = m.namedGroup('userinfo');
    final host = m.namedGroup('host');
    final port = m.namedGroup('port');

    if (userInfo != null) {
      final parts = userInfo.split(':');
      res['username'] = parts.isNotEmpty ? parts[0] : '';
      res['password'] = parts.length == 2 ? parts[1] : null;
    }

    res['host'] = host;
    res['port'] = port;

    uri = uri.substring(m.end);
  }

  // Path.
  m = _pathRegex.firstMatch(uri);

  res['path'] = const <String>[];

  if (m != null) {
    final paths = m.group(1)?.split('/') ?? const [];

    res['path'] = [
      for (final item in paths) if (item.isNotEmpty) item,
    ];

    uri = uri.substring(m.end);
  }

  // Query.
  m = _queryRegex.firstMatch(uri);

  res['query'] = <String>[];

  if (m != null) {
    final queries = m.group(1)?.split('&') ?? const [];

    for (final item in queries) {
      final q = item.split('=');

      res['query'].add(q[0]);

      if (q.length == 2) {
        res['query'].add(q[1]); // Value or empty.
      } else {
        res['query'].add(null); // No value.
      }
    }

    uri = uri.substring(m.end);
  }

  // Fragment.
  m = _fragmentRegex.firstMatch(uri);

  if (m != null) {
    res['fragment'] = m.group(1);
  }

  return res;
}

class MalformedUriException implements Exception {
  final String message;

  const MalformedUriException(this.message);

  @override
  String toString() {
    return message;
  }
}
