import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:brotli/brotli.dart';
import 'package:restio/src/core/response/compression_type.dart';
import 'package:restio/src/utils/output_buffer.dart';

typedef ChunkReceivedCallback = void Function(List<int> chunk);

class Decompressor {
  final CompressionType compressionType;
  final Stream<List<int>> data;
  final ChunkReceivedCallback onChunkReceived;
  final void Function() onDone;
  StreamSubscription _subscription;

  Decompressor({
    this.compressionType,
    this.data,
    this.onChunkReceived,
    this.onDone,
  });

  Future<List<int>> decompress() {
    final completer = Completer<List<int>>.sync();
    final output = OutputBuffer();
    ByteConversionSink sink;

    if (compressionType == null ||
        compressionType == CompressionType.notCompressed) {
      sink = output;
    } else if (compressionType == CompressionType.gzip) {
      sink = gzip.decoder.startChunkedConversion(output);
    } else if (compressionType == CompressionType.deflate) {
      sink = zlib.decoder.startChunkedConversion(output);
    } else if (compressionType == CompressionType.brotli) {
      sink = brotli.decoder.startChunkedConversion(output);
    } else {
      throw UnsupportedError(
        'Compression type $compressionType is unsupported',
      );
    }

    _subscription = data.listen(
      (chunk) {
        onChunkReceived?.call(chunk);
        sink.add(chunk);
      },
      onDone: () {
        sink.close();
        onDone?.call();
        completer.complete(output.bytes);
      },
      onError: completer.completeError,
      cancelOnError: true,
    );

    return completer.future;
  }

  void pause() {
    if (!isPaused) {
      _subscription?.pause();
    }
  }

  bool get isPaused => _subscription != null && _subscription.isPaused;

  void resume() {
    _subscription?.resume();
  }

  void stop() {
    _subscription?.cancel();
  }
}
