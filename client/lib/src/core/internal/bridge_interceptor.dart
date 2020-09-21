import 'dart:convert';
import 'dart:io';

import 'package:restio/src/common/helpers.dart';
import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/response/response.dart';
import 'package:restio/src/core/response/response_stream.dart';

class BridgeInterceptor implements Interceptor {
  final Restio client;

  BridgeInterceptor(this.client);

  @override
  Future<Response> intercept(Chain chain) async {
    final request = chain.request;

    final headersBuilder = request.headers.toBuilder();

    // Accept-Encoding.
    if (!request.headers.has(HttpHeaders.acceptEncodingHeader) &&
        !request.headers.has(HttpHeaders.rangeHeader)) {
      headersBuilder.set('Accept-Encoding', 'gzip, deflate, br');
    }

    // Content-Type.
    if (!request.headers.has(HttpHeaders.contentTypeHeader) &&
        request.body?.contentType != null) {
      headersBuilder.set('Content-Type', request.body.contentType.value);
    }

    // User-Agent.
    if (!request.headers.has(HttpHeaders.userAgentHeader)) {
      if (request.options.userAgent != null) {
        headersBuilder.set('User-Agent', request.options.userAgent);
      } else {
        headersBuilder.set('User-Agent', 'Restio/${Restio.version}');
      }
    }

    final response =
        await chain.proceed(request.copyWith(headers: headersBuilder.build()));
    Converter<List<int>, List<int>> decoder;

    final contentEncoding = response.headers
        .value(HttpHeaders.contentEncodingHeader)
        ?.trim()
        ?.toLowerCase();

    if ((contentEncoding == 'gzip' ||
            contentEncoding == 'deflate' ||
            contentEncoding == 'br') &&
        response.hasBody) {
      decoder = decoderByContentEncoding(contentEncoding);
    }

    final data = response.body.data;

    return response.copyWith(
      body: ResponseBody(
        data is ResponseStream ? data : ResponseStream(data),
        contentType: response.body.contentType,
        contentLength: response.body.contentLength,
        decoder: decoder,
      ),
    );
  }
}
