import 'dart:io';

import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

class BearerAuthenticator extends Authenticator {
  final String token;
  final String prefix;

  const BearerAuthenticator({
    this.token,
    this.prefix = 'Bearer',
  }) : assert(prefix != null);

  @override
  Future<Request> authenticate(Response response) async {
    final headers = response.request.headers;

    // Verifica se o retorno é causado por um proxy.
    final isProxy = response.code == HttpStatus.proxyAuthenticationRequired;

    if (!isProxy && headers.has(HttpHeaders.authorizationHeader)) {
      return null;
    }

    if (isProxy && headers.has(HttpHeaders.proxyAuthorizationHeader)) {
      return null;
    }

    // Não é obrigatório um challenge!
    return _authenticate(response.request, isProxy);
  }

  Request _authenticate(
    Request request,
    bool isProxy,
  ) {
    final headerName = isProxy ? 'Proxy-Authorization' : 'Authorization';

    final headerValue = '$prefix $token';

    return request.copyWith(
      headers:
          (request.headers.toBuilder()..set(headerName, headerValue)).build(),
    );
  }
}
