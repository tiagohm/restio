import 'dart:convert';

typedef ChunkReceivedCallback = void Function(List<int> chunk);

class Decompressor extends Converter<List<int>, List<int>> {
  final Converter<List<int>, List<int>> decoder;
  final ChunkReceivedCallback onChunkReceived;

  const Decompressor(
    this.decoder, [
    this.onChunkReceived,
  ]);

  @override
  List<int> convert(List<int> input) {
    return decoder?.convert(input) ?? input;
  }

  @override
  Sink<List<int>> startChunkedConversion(Sink<List<int>> sink) {
    sink = _ChunkReceivedSink(sink, onChunkReceived);
    return decoder?.startChunkedConversion(sink) ?? sink;
  }
}

class _ChunkReceivedSink extends ByteConversionSinkBase {
  final Sink<List<int>> sink;
  final ChunkReceivedCallback onChunkReceived;
  var _isClosed = false;

  _ChunkReceivedSink(this.sink, [this.onChunkReceived]);

  @override
  void add(List<int> data) {
    onChunkReceived?.call(data);
    sink.add(data);
  }

  @override
  void close() {
    if (_isClosed) {
      return;
    }

    if (!_isClosed) {
      _isClosed = true;
      onChunkReceived?.call(null);
      sink.close();
    }
  }
}
