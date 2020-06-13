final _schemeRegex = RegExp(r'^([^:]*):');
final _authoritySlashRegex = RegExp(r'^//');
final _authorityRegex = RegExp(
    r'^(?:(?<userinfo>.*)@)?(?<host>(?:(?!\[)[^:/?#]+)|\[.*\])(?::(?<port>[^/?#]*))?');
final _pathRegex = RegExp(r'^([^?#]*)');
final _queryRegex = RegExp(r'^\?([^#]*)');
final _fragmentRegex = RegExp(r'^#(.*)');

Map<String, dynamic> parseUri(String uri) {
  if (uri == null || uri.isEmpty) {
    return null;
  }

  final res = <String, dynamic>{};

  // Scheme.
  var m = _schemeRegex.firstMatch(uri);

  if (m != null) {
    final scheme = m.group(1);
    uri = uri.substring(m.end);
    res['scheme'] = scheme;
  }

  // Authority.
  m = _authoritySlashRegex.firstMatch(uri);

  if (m != null) {
    uri = uri.substring(2);

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
