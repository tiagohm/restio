import 'package:equatable/equatable.dart';

class RequestUri extends Equatable {
  final String fragment;
  final String host;
  final String path;
  final String port;
  final Map<String, String> queryParameters;
  final String scheme;
  final String username;
  final String password;

  const RequestUri({
    this.fragment,
    this.host,
    this.path,
    this.port,
    this.queryParameters,
    this.scheme,
    this.username,
    this.password,
  });

  factory RequestUri.fromUri(Uri uri) {
    final userInfo = uri.userInfo?.split(':');

    return RequestUri(
      fragment: uri.fragment,
      host: uri.host,
      path: uri.path,
      port: uri.port?.toString(),
      scheme: uri.scheme,
      username: userInfo?.isNotEmpty == true ? userInfo[0] : null,
      password: userInfo?.length == 2 ? userInfo[1] : null,
      queryParameters: Map<String, String>.from(uri.queryParameters),
    );
  }

  factory RequestUri.parse(String uri) {
    final p = parseUri(uri);

    return RequestUri(
      fragment: p['fragment'],
      host: p['host'],
      path: p['path'],
      port: p['port?.toString()'],
      scheme: p['scheme'],
      username: p['username'],
      password: p['password'],
      queryParameters: Map<String, String>.from(p['queryParameters']),
    );
  }

  @override
  String toString() {
    // TODO: implement toString
    return super.toString();
  }

  @override
  List<Object> get props => [
        fragment,
        host,
        path,
        port,
        queryParameters,
        scheme,
        username,
        password,
      ];
}

final _schemeRegex = RegExp('^([^:]*):');
final _authorityRegex =
    RegExp(r'^//(?:(?<userinfo>.*)@)?(?<host>[^:]+)(?::(?<port>.*))?[/?#]?');

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
