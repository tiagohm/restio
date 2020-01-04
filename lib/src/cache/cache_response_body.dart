import 'package:restio/src/cache/cache.dart';
import 'package:restio/src/cache/snapshot.dart';
import 'package:restio/src/compression_type.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/response_body.dart';

class CacheResponseBody extends ResponseBody {
  final Snapshot snapshot;

  CacheResponseBody(
    this.snapshot, {
    MediaType contentType,
    int contentLength,
    CompressionType compressionType,
    void Function(int sent, int total, bool done) onProgress,
  }) : super(
          snapshot.source(Cache.entryBody),
          contentType: contentType,
          contentLength: contentLength,
          compressionType: compressionType,
          onProgress: onProgress,
        );
}
