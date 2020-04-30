import 'dart:io';

import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/cookie/cookie_jar.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/response/response.dart';

class CookieInterceptor implements Interceptor {
  final CookieJar jar;

  CookieInterceptor(this.jar);

  @override
  Future<Response> intercept(Chain chain) async {
    var request = chain.request;

    // TODO: O usuário pode ter seu próprio header de cookie.
    // Devemos apenas concatená-lo?
    if (jar != null) {
      final cookies = await jar.load(request);

      final cookieHeader = _cookieHeader(cookies);

      // Se tem cookies para enviar, seta no header.
      if (cookieHeader != null && cookieHeader.isNotEmpty) {
        request = request.copyWith(
          headers: (request.headers.toBuilder()
                ..set(HttpHeaders.cookieHeader, cookieHeader))
              .build(),
        );
      }
      // Se não, remove para não ficar da requisição antes do redirecionamento.
      // TODO: Poderia ter uma opção para desabilitar isto?
      else {
        request = request.copyWith(
          headers: (request.headers.toBuilder()
                ..removeAll(HttpHeaders.cookieHeader))
              .build(),
        );
      }
    }

    final response = await chain.proceed(request);

    if (jar != null && response != null) {
      await jar.save(response);
    }

    return response;
  }

  String _cookieHeader(List<Cookie> cookies) {
    return cookies.map((item) => '${item.name}=${item.value}').join('; ');
  }
}
