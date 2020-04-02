import 'package:equatable/equatable.dart';
import 'package:restio/src/queries.dart';

class RequestUri extends Equatable {
  final String fragment;
  final String host;
  final List<String> paths;
  final String port;
  final Queries queries;
  final String scheme;
  final String username;
  final String password;

  const RequestUri({
    this.fragment,
    this.host,
    List<String> paths,
    this.port,
    Queries queries,
    this.scheme,
    this.username,
    this.password,
  })  : paths = paths ?? const [],
        queries = queries ?? Queries.empty;

  factory RequestUri.fromUri(Uri uri) {
    final userInfo = uri.userInfo.isNotEmpty ? uri.userInfo.split(':') : null;

    return RequestUri(
      fragment: uri.hasFragment ? uri.fragment : null,
      host: uri.host,
      paths: uri.pathSegments,
      port: uri.port?.toString(),
      scheme: uri.scheme,
      username: userInfo?.isNotEmpty == true ? userInfo[0] : null,
      password: userInfo?.length == 2 ? userInfo[1] : null,
      queries: _obtainQueriesFromMap(uri.queryParametersAll),
    );
  }

  static Queries _obtainQueriesFromList(
    List<String> queries,
  ) {
    final builder = QueriesBuilder();

    for (var i = 0; i < queries.length; i += 2) {
      builder.add(queries[i], queries[i + 1]);
    }

    return builder.build();
  }

  static Queries _obtainQueriesFromMap(
    Map<String, List<String>> queries,
  ) {
    final builder = QueriesBuilder();

    queries.forEach((key, values) {
      for (final item in values) {
        builder.add(key, item);
      }
    });

    return builder.build();
  }

  factory RequestUri.parse(String uri) {
    final p = parseUri(uri);

    return RequestUri(
      fragment: p['fragment'],
      host: p['host'],
      paths: p['path'],
      port: p['port'],
      scheme: p['scheme'],
      username: p['username'],
      password: p['password'],
      queries: _obtainQueriesFromList(p['query']),
    );
  }

  RequestUri copyWith({
    String fragment,
    String host,
    List<String> paths,
    port,
    Queries queries,
    String scheme,
    String username,
    String password,
  }) {
    return RequestUri(
      fragment: fragment ?? this.fragment,
      host: host ?? this.host,
      paths: paths ?? this.paths,
      port: port?.toString() ?? this.port,
      queries: queries ?? this.queries,
      scheme: scheme ?? this.scheme,
      username: username ?? this.username,
      password: password ?? this.password,
    );
  }

  @override
  String toString() {
    final sb = StringBuffer();

    if (scheme != null) {
      sb.write(scheme);
      sb.write(':');
    }

    if (host != null) {
      if (scheme != null) {
        sb.write('//');
      }

      if (hasAuthority) {
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

    for (final item in paths) {
      sb.write('/');
      sb.write(item);
    }

    if (queries.isNotEmpty) {
      sb.write('?');
      sb.write(queries.toQueryString());
    }

    if (fragment != null) {
      sb.write('#');
      sb.write(fragment);
    }

    return sb.toString();
  }

  Uri toUri() {
    return Uri.parse(toString());
  }

  static const _defaultPortMap = {
    'acap': 674,
    'afp': 548,
    'dict': 2628,
    'dns': 53,
    'ftp': 21,
    'git': 9418,
    'gopher': 70,
    'http': 80,
    'https': 443,
    'imap': 143,
    'ipp': 631,
    'ipps': 631,
    'irc': 194,
    'ircs': 6697,
    'ldap': 389,
    'ldaps': 636,
    'mms': 1755,
    'msrp': 2855,
    'mtqp': 1038,
    'nfs': 111,
    'nntp': 119,
    'nntps': 563,
    'pop': 110,
    'prospero': 1525,
    'redis': 6379,
    'rsync': 873,
    'rtsp': 554,
    'rtsps': 322,
    'rtspu': 5005,
    'sftp': 22,
    'smb': 445,
    'snmp': 161,
    'ssh': 22,
    'svn': 3690,
    'telnet': 23,
    'ventrilo': 3784,
    'vnc': 5900,
    'wais': 210,
    'ws': 80,
    'wss': 443,
  };

  int get effectivePort {
    final schemePort = _defaultPortMap[scheme?.toLowerCase()] ?? 0;
    return port == null ? schemePort : int.tryParse(port) ?? 0;
  }

  bool get hasDefaultPort => _defaultPortMap[scheme] == effectivePort;

  bool get hasAuthority => username != null || password != null;

  String get path {
    return paths.isNotEmpty ? '/${paths.join('/')}' : '';
  }

  @override
  List<Object> get props => [
        fragment,
        host,
        paths,
        port,
        queries,
        scheme,
        username,
        password,
      ];
}

final _schemeRegex = RegExp(r'^([^:]*):');
final _authorityRegex = RegExp(
    r'^//(?:(?<userinfo>.*)@)?(?<host>(?:(?!\[)[^:/]+)|\[.*\])(?::(?<port>[^/?#]*))?');
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
      for (var i = 0; i < paths.length; i++)
        if (i > 0 || paths[i].isNotEmpty) paths[i],
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
