import 'dart:async';
import 'dart:convert' as convert;

import 'package:restio/src/compression_type.dart';
import 'package:restio/src/decompressor.dart';
import 'package:restio/src/media_type.dart';

class ResponseBody {
  final MediaType contentType;
  final Stream<List<int>> data;
  final int contentLength;
  final CompressionType compressionType;
  Decompressor _decompressor;
  final void Function(int sent, int total, bool done) onProgress;

  ResponseBody({
    this.contentType,
    this.data,
    this.contentLength,
    this.compressionType,
    this.onProgress,
  });

  factory ResponseBody.fromBytes(
    List<int> data, {
    MediaType contentType,
    int contentLength = -1,
    CompressionType compressionType = CompressionType.notCompressed,
    void Function(int sent, int total, bool done) onProgress,
  }) {
    return ResponseBody(
      contentType: contentType,
      data: Stream.fromIterable([data]),
      contentLength: contentLength == -1 ? data.length : contentLength,
      compressionType: compressionType,
      onProgress: onProgress,
    );
  }

  factory ResponseBody.fromString(
    String text, {
    MediaType contentType,
    int contentLength = -1,
    void Function(int sent, int total, bool done) onProgress,
  }) {
    final encoding = contentType?.encoding ?? convert.utf8;
    return ResponseBody(
      contentType: contentType,
      data: Stream.fromFuture(Future(() => encoding.encode(text))),
      contentLength: contentLength,
      compressionType: CompressionType.notCompressed,
      onProgress: onProgress,
    );
  }

  factory ResponseBody.fromStream(
    Stream<List<int>> data, {
    MediaType contentType,
    int contentLength = -1,
    CompressionType compressionType = CompressionType.notCompressed,
    void Function(int sent, int total, bool done) onProgress,
  }) {
    return ResponseBody(
      contentType: contentType,
      data: data,
      contentLength: contentLength,
      compressionType: compressionType,
      onProgress: onProgress,
    );
  }

  Future<List<int>> raw([
    bool decompress = true,
  ]) {
    var sent = 0;
    _decompressor = Decompressor(
      compressionType:
          decompress ? compressionType : CompressionType.notCompressed,
      data: data,
      onChunkReceived: (chunk) {
        sent += chunk.length;
        onProgress?.call(sent, contentLength, false);
      },
      onDone: () {
        onProgress?.call(sent, contentLength, true);
        _decompressor = null;
      },
    );

    return _decompressor.decompress();
  }

  Future<List<int>> compressed() => raw(false);

  Future<List<int>> decompressed() => raw(true);

  Future<String> string() async {
    final encoded = await raw(true);
    return contentType?.encoding != null
        ? contentType.encoding.decode(encoded)
        : convert.utf8.decode(encoded);
  }

  Future<dynamic> json() async {
    return convert.json.decode(await string());
  }

  void pause() {
    _decompressor?.pause();
  }

  void resume() {
    _decompressor?.resume();
  }

  bool get isPaused => _decompressor != null && _decompressor.isPaused;

  @override
  String toString() {
    return 'ResponseBody { contentType: $contentType, contentLength: $contentLength, compressionType: $compressionType }';
  }
}
