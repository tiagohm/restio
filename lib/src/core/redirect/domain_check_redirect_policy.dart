import 'package:restio/src/core/redirect/redirect.dart';
import 'package:restio/src/core/redirect/redirect_policy.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

class DomainCheckRedirectPolicy implements RedirectPolicy {
  final List<String> hostnames;

  const DomainCheckRedirectPolicy(this.hostnames);

  @override
  bool apply(
    Response response,
    Request next,
    List<Redirect> redirects,
  ) {
    final host = next.uri.host;
    return hostnames != null && hostnames.contains(host);
  }
}
