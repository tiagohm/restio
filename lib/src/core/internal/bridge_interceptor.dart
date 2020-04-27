import 'dart:io';

import 'package:restio/src/common/decompressor.dart';
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

    var transparentDecoding = false;

    // Accept-Encoding.
    if (!request.headers.has(HttpHeaders.acceptEncodingHeader) &&
        !request.headers.has(HttpHeaders.rangeHeader)) {
      transparentDecoding = true;
    }

    final response = await chain.proceed(request);
    dynamic decoder;

    final contentEncoding = response.headers
        .value(HttpHeaders.contentEncodingHeader)
        ?.trim()
        ?.toLowerCase();

    if (transparentDecoding &&
        (contentEncoding == 'gzip' ||
            contentEncoding == 'deflate' ||
            contentEncoding == 'br') &&
        response.hasBody) {
      decoder = decoderByContentEncoding(contentEncoding);
    }

    var total = 0;

    final decompressor = Decompressor(decoder, (data) {
      if (client.onDownloadProgress != null) {
        // End.
        if (data == null) {
          client.onDownloadProgress(response, 0, total, true);
        } else {
          total += data.length;
          client.onDownloadProgress(response, data.length, total, false);
        }
      }
    });

    final stream = response.body.data;
    final data = stream is ResponseStream ? stream : ResponseStream(stream);

    return response.copyWith(
      body: ResponseBody(
        data,
        contentType: response.body.contentType,
        contentLength: response.body.contentLength,
        decompressor: decompressor,
      ),
    );
  }
}
