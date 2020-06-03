import 'package:equatable/equatable.dart';
import 'package:restio/restio.dart';
import 'package:restio/src/common/parse_uri.dart';
import 'package:restio/src/core/request/query/queries.dart';
import 'package:restio/src/core/request/query/queries_builder.dart';

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

  factory RequestUri.fromUri(
    Uri uri, {
    bool keepEqualSign = false,
  }) {
    final userInfo = uri.userInfo.isNotEmpty ? uri.userInfo.split(':') : null;

    return RequestUri(
      fragment: uri.hasFragment ? uri.fragment : null,
      host: uri.host,
      paths: uri.pathSegments,
      port: uri.port?.toString(),
      scheme: uri.scheme,
      username: userInfo?.isNotEmpty == true ? userInfo[0] : null,
      password: userInfo?.length == 2 ? userInfo[1] : null,
      queries: _obtainQueriesFromMap(uri.queryParametersAll, keepEqualSign),
    );
  }

  factory RequestUri.parse(
    String uri, {
    bool keepEqualSign = false,
    String baseUri,
  }) {
    final p = parseUri(uri) ?? const {};
    final base = parseUri(baseUri) ?? const {};
    final paths = <String>[];
    final queries = <String>[];

    if (base.containsKey('path')) {
      paths.addAll(base['path']);
    }

    if (p.containsKey('path')) {
      paths.addAll(p['path']);
    }

    // Remove duplicates.
    if (baseUri != null &&
        baseUri.endsWith('/') &&
        paths.isNotEmpty &&
        paths[0].isEmpty) {
      paths.removeAt(0);
    }

    if (base.containsKey('query')) {
      queries.addAll(base['query']);
    }

    if (p.containsKey('query')) {
      queries.addAll(p['query']);
    }

    print(queries);
    print(base['host']);

    return RequestUri(
      fragment: p['fragment'],
      host: p['host'] ?? base['host'],
      paths: paths,
      port: p['port'] ?? base['port'],
      scheme: p['scheme'] ?? base['scheme'],
      username: p['username'] ?? base['username'],
      password: p['password'] ?? base['password'],
      queries: _obtainQueriesFromList(queries, keepEqualSign),
    );
  }

  static Queries _obtainQueriesFromList(
    List<String> queries,
    bool keepEqualSign,
  ) {
    final builder = QueriesBuilder(keepEqualSign: keepEqualSign);

    if (queries != null) {
      for (var i = 0; i < queries.length; i += 2) {
        try {
          builder.add(queries[i], queries[i + 1]);
        } catch (e) {
          // nada.
        }
      }
    }

    return builder.build();
  }

  static Queries _obtainQueriesFromMap(
    Map<String, List<String>> queries,
    bool keepEqualSign,
  ) {
    final builder = QueriesBuilder(keepEqualSign: keepEqualSign);

    queries.forEach((key, values) {
      for (final item in values) {
        try {
          builder.add(key, item);
        } catch (e) {
          // nada.
        }
      }
    });

    return builder.build();
  }

  RequestUri copyWith({
    String fragment,
    String host,
    List<String> paths,
    dynamic port,
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

  String toUriString() {
    final sb = StringBuffer();

    if (scheme != null) {
      sb.write(scheme);
      sb.write('://');
    }

    if (host != null) {
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

    if (hasQuery) {
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
    return Uri.parse(toUriString());
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

  static int defaultPort(String scheme) {
    return _defaultPortMap[scheme?.toLowerCase()] ?? -1;
  }

  int get effectivePort {
    final schemePort = defaultPort(scheme) ?? -1;
    return port == null ? schemePort : int.tryParse(port) ?? -1;
  }

  bool get hasDefaultPort => defaultPort(scheme) == effectivePort;

  bool get hasAuthority => username != null || password != null;

  bool get hasQuery => queries != null && queries.isNotEmpty;

  String get path {
    return (scheme == null || scheme.isEmpty) && paths.isEmpty
        ? null
        : paths.isNotEmpty ? '/${paths.join('/')}' : '/';
  }

  String toHostHeader({bool includeDefaultPort = false}) {
    final host = this.host.contains(':') ? '[${this.host}]' : this.host;
    return includeDefaultPort || !hasDefaultPort ? '$host:$port' : host;
  }

  @override
  String toString() {
    return 'RequestUri { scheme: $scheme, username: $username,'
        ' password: $password, host: $host, port: $port, paths: $paths,'
        ' queries: $queries, fragment: $fragment }';
  }

  bool canReuseConnectionFor(RequestUri uri) {
    return host == uri.host &&
        effectivePort == uri.effectivePort &&
        scheme == uri.scheme;
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
