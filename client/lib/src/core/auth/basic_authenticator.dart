import 'dart:convert';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/challenge.dart';
import 'package:restio/src/core/response/response.dart';

class BasicAuthenticator extends Authenticator {
  final String username;
  final String password;
  @override
  final bool noRedirect;

  const BasicAuthenticator({
    @required this.username,
    @required this.password,
    this.noRedirect = false,
  });

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
    for (final challenge in response.challenges) {
      if (challenge.isBasic) {
        return _authenticate(challenge, response.request, isProxy);
      }
    }

    return _authenticate(null, response.request, isProxy);
  }

  @override
  Future<Request> authenticateNoRedirect(Request request) async {
    return _authenticate(null, request, false);
  }

  Request _authenticate(
    Challenge challenge,
    Request request,
    bool isProxy,
  ) {
    final headerName = isProxy ? 'Proxy-Authorization' : 'Authorization';

    return request.copyWith(
      headers: (request.headers.toBuilder()
            ..set(
              headerName,
              header(username, password, encoding: challenge?.encoding),
            ))
          .build(),
    );
  }

  static String header(
    String username,
    String password, {
    Encoding encoding,
  }) {
    encoding ??= utf8;
    final usernameAndPassword = '$username:$password';
    final hash = base64.encode(encoding.encode(usernameAndPassword));
    return 'Basic $hash';
  }
}
