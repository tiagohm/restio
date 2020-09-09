import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/request/request.dart';

typedef AuthenticatorSelector = Authenticator Function(Response response);

class MultiAuthenticator implements Authenticator {
  final List<Authenticator> authenticators;
  final AuthenticatorSelector selector;

  const MultiAuthenticator(
    this.authenticators, {
    this.selector,
  }) : assert(authenticators != null);

  @override
  Future<Request> authenticate(Response response) async {
    final auth = selector?.call(response);

    if (auth != null) {
      return auth.authenticate(response);
    } else {
      for (final auth in authenticators) {
        final request = auth?.authenticate(response);

        if (request != null) {
          return request;
        }
      }
    }

    return null;
  }
}
