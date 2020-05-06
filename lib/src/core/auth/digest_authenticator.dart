import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/auth/nonce.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

class DigestAuthenticator extends Authenticator {
  final String username;
  final String password;

  const DigestAuthenticator({
    this.username,
    this.password,
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

    for (final challenge in response.challenges) {
      // É necessário pelo menos um challenge.
      if (challenge.isDigest) {
        final realm = challenge.realm;
        final nonce = challenge.parameters['nonce'];
        final method = response.request.method;
        final path = response.request.uri.path;
        final opaque = challenge.parameters['opaque'];
        // final stale = challenge.parameters['stale'];
        final algorithm = challenge.parameters['algorithm'] ?? 'MD5';
        final qop = challenge.parameters['qop'];
        final cnonce = Nonce.random(8).value;
        const nonceCount = '00000001';

        final headerValue = _buildHeader(
          username: username,
          realm: realm,
          nonce: nonce,
          cnonce: cnonce,
          nonceCount: nonceCount,
          uri: path,
          qop: qop,
          method: method,
          opaque: opaque,
          algorithm: algorithm,
        );

        final headerName = isProxy ? 'Proxy-Authorization' : 'Authorization';

        return response.request.copyWith(
          headers: (response.request.headers.toBuilder()
                ..set(headerName, headerValue))
              .build(),
        );
      }
    }

    return null;
  }

  String _buildHeader({
    String username,
    String realm,
    String nonce,
    String cnonce,
    String nonceCount,
    String uri,
    String qop,
    String method,
    String opaque,
    String algorithm,
  }) {
    final hash = _encodeToDigestHash(
      username: username,
      password: password,
      realm: realm,
      nonce: nonce,
      method: method,
      uri: uri,
      algorithm: algorithm,
      qop: qop,
      cnonce: cnonce,
      nonceCount: nonceCount,
    );

    final sb = StringBuffer();

    sb.write(
      'Digest username="$username", realm="$realm", nonce="$nonce", uri="$uri"',
    );

    if (qop == 'auth' || qop == 'auth-int') {
      sb.write(', nc=$nonceCount, qop=auth, cnonce="$cnonce"');
    }

    sb.write(', response="$hash"');

    if (opaque != null) {
      sb.write(', opaque="$opaque"');
    }

    sb.write(', algorithm="$algorithm"');

    return sb.toString().trim();
  }

  String _encodeToDigestHash({
    String username,
    String password,
    String realm,
    String nonce,
    String method,
    String uri,
    String algorithm,
    String qop,
    String cnonce,
    String nonceCount,
  }) {
    var ha1 = '';
    final hashAlgorithm = algorithm == 'SHA-256' ? sha256 : md5;

    if (algorithm == 'MD5-sess') {
      ha1 = hashAlgorithm
          .convert('$username:$realm:$password'.codeUnits)
          .toString();
      ha1 = hashAlgorithm.convert('$ha1:$nonce:$cnonce'.codeUnits).toString();
    } else {
      ha1 = hashAlgorithm
          .convert('$username:$realm:$password'.codeUnits)
          .toString();
    }

    final ha2 = hashAlgorithm.convert('$method:$uri'.codeUnits).toString();

    if (qop == 'auth' || qop == 'auth-int') {
      return hashAlgorithm
          .convert('$ha1:$nonce:$nonceCount:$cnonce:$qop:$ha2'.codeUnits)
          .toString();
    } else {
      return hashAlgorithm.convert('$ha1:$nonce:$ha2'.codeUnits).toString();
    }
  }
}
