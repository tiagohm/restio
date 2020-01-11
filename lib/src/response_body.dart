import 'dart:async';
import 'dart:convert' as convert;

import 'package:restio/src/compression_type.dart';
import 'package:restio/src/decompressor.dart';
import 'package:restio/src/media_type.dart';
import 'package:restio/src/response_body_data.dart';

class ResponseBody {
  final Stream<List<int>> _data;
  final MediaType contentType;
  final int contentLength;
  final CompressionType compressionType;
  final void Function(int sent, int total, bool done) onProgress;

  ResponseBody(
    this._data, {
    this.contentType,
    this.contentLength,
    this.compressionType,
    this.onProgress,
  });

  factory ResponseBody.bytes(
    List<int> data, {
    MediaType contentType,
    int contentLength = -1,
    CompressionType compressionType = CompressionType.notCompressed,
    void Function(int sent, int total, bool done) onProgress,
  }) {
    return ResponseBody(
      Stream.fromIterable([data]),
      contentType: contentType,
      contentLength: contentLength == -1 ? data.length : contentLength,
      compressionType: compressionType,
      onProgress: onProgress,
    );
  }

  factory ResponseBody.string(
    String text, {
    MediaType contentType,
    int contentLength = -1,
    void Function(int sent, int total, bool done) onProgress,
  }) {
    final encoding = contentType?.encoding ?? convert.utf8;
    return ResponseBody(
      Stream.fromFuture(Future(() => encoding.encode(text))),
      contentType: contentType,
      contentLength: contentLength,
      compressionType: CompressionType.notCompressed,
      onProgress: onProgress,
    );
  }

  factory ResponseBody.stream(
    Stream<List<int>> data, {
    MediaType contentType,
    int contentLength = -1,
    CompressionType compressionType = CompressionType.notCompressed,
    void Function(int sent, int total, bool done) onProgress,
  }) {
    return ResponseBody(
      data,
      contentType: contentType,
      contentLength: contentLength,
      compressionType: compressionType,
      onProgress: onProgress,
    );
  }

  ResponseBodyData get data {
    return _ResponseBodyData(this);
  }

  Future close() async {
    return true;
  }

  @override
  String toString() {
    return 'ResponseBody { contentType: $contentType, contentLength: $contentLength, compressionType: $compressionType }';
  }
}

class _ResponseBodyData extends ResponseBodyData {
  final ResponseBody body;
  Decompressor _decompressor;

  _ResponseBodyData(this.body);

  @override
  bool get isPaused => _decompressor != null || _decompressor.isPaused;

  @override
  bool get isStopped => _decompressor == null;

  @override
  Stream<List<int>> get stream => body._data;

  @override
  void pause() {
    _decompressor?.pause();
  }

  @override
  void resume() {
    _decompressor?.resume();
  }

  Future<List<int>> _raw({
    bool decompress = true,
  }) {
    var sent = 0;

    _decompressor = Decompressor(
      compressionType:
          decompress ? body.compressionType : CompressionType.notCompressed,
      data: body._data,
      onChunkReceived: (chunk) {
        sent += chunk.length;
        body.onProgress?.call(sent, body.contentLength, false);
      },
      onDone: () {
        body.onProgress?.call(sent, body.contentLength, true);
        _decompressor = null;
      },
    );

    return _decompressor.decompress();
  }

  @override
  Future<List<int>> raw() => _raw(decompress: false);

  @override
  Future<List<int>> decompressed() => _raw(decompress: true);

  @override
  Future<String> string() async {
    final encoded = await decompressed();

    return body.contentType?.encoding != null
        ? body.contentType.encoding.decode(encoded)
        : convert.utf8.decode(encoded);
  }

  @override
  Future<dynamic> json() async {
    return convert.json.decode(await string());
  }
}
