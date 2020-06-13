import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:restio/src/core/auth/authenticator.dart';
import 'package:restio/src/core/auth/nonce.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/challenge.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:utf/utf.dart';

enum HawkAlgorithm { sha1, sha256 }

class HawkAuthenticator extends Authenticator {
  final String id;
  final String key;
  final HawkAlgorithm algorithm;
  final String ext;

  const HawkAuthenticator({
    this.id,
    this.key,
    this.algorithm = HawkAlgorithm.sha256,
    this.ext,
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
      if (challenge.isHawk) {
        return _authenticate(challenge, response.request, isProxy);
      }
    }

    return _authenticate(null, response.request, isProxy);
  }

  Request _authenticate(
    Challenge challenge,
    Request request,
    bool isProxy,
  ) {
    final method = request.method;
    final uri = request.uri;

    final headerName = isProxy ? 'Proxy-Authorization' : 'Authorization';

    final headerValue = _buildHeader(
      method: method ?? '',
      uri: uri,
      id: id,
      key: key,
      ext: ext ?? '',
      algorithm: algorithm,
    );

    return request.copyWith(
      headers:
          (request.headers.toBuilder()..set(headerName, headerValue)).build(),
    );
  }

  static String _buildHeader({
    String method = '',
    RequestUri uri,
    String id,
    String key,
    HawkAlgorithm algorithm,
    String ext,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nonce = Nonce.random(6).value;
    final queries = uri.queries.toQueryString();
    final resource = queries.isEmpty ? uri.path : '${uri.path}?$queries';
    final mac = _encodeToHawkHash(
      key: key,
      timestamp: timestamp,
      nonce: nonce,
      method: method,
      resource: resource,
      host: uri.host,
      port: uri.effectivePort,
      ext: ext,
      isSha256: algorithm == HawkAlgorithm.sha256,
    );

    return 'Hawk id="$id", ts="$timestamp",'
        ' nonce="$nonce"${ext.isNotEmpty ? ', ext="$ext"' : ''}, mac="$mac"';
  }

  static String _encodeToHawkHash({
    String key,
    int timestamp,
    String nonce,
    String method = '',
    String resource = '',
    String host,
    int port,
    String hash = '',
    String ext = '',
    bool isSha256,
  }) {
    final normalizedReqStr = 'hawk.1.header\n$timestamp\n$nonce\n$method\n'
        '$resource\n$host\n$port\n$hash\n$ext\n';
    final hmac = Hmac(isSha256 ? sha256 : sha1, utf8.encode(key));
    final bytes = hmac.convert(encodeUtf8(normalizedReqStr)).bytes;
    return base64.encode(bytes);
  }
}
