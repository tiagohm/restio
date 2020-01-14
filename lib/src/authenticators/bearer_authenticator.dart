import 'dart:io';

import 'package:restio/src/authenticator.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

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
    Request originalRequest,
    bool isProxy,
  ) {
    final headerName = isProxy
        ? HttpHeaders.proxyAuthorizationHeader
        : HttpHeaders.authorizationHeader;

    final headerValue = '$prefix $token';

    return originalRequest.copyWith(
      headers: (originalRequest.headers.toBuilder()
            ..set(headerName, headerValue))
          .build(),
    );
  }

  @override
  List<Object> get props => [token, prefix];
}
