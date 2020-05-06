import 'package:globbing/globbing.dart';

final _matchers = <String, GlobMatcher>{};

class GlobMatcher {
  final Glob glob;

  GlobMatcher._(this.glob);

  factory GlobMatcher(String host) {
    ArgumentError.checkNotNull(host, 'host');
    _matchers[host] ??= GlobMatcher._(Glob(host));
    return _matchers[host];
  }

  bool matches(String host) => glob.match(host);
}
