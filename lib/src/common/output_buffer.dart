import 'dart:convert';
import 'dart:typed_data';

class OutputBuffer extends ByteConversionSinkBase {
  List<List<int>> _chunks = <List<int>>[];
  int _contentLength = 0;
  Uint8List _bytes;

  @override
  void add(List<int> chunk) {
    _chunks.add(chunk);
    _contentLength += chunk.length;
  }

  @override
  void close() {
    if (_bytes != null) {
      return;
    }

    _bytes = Uint8List(_contentLength);
    var offset = 0;

    for (final chunk in _chunks) {
      _bytes.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }

    _chunks = null;
  }

  int get length => _contentLength;

  Uint8List get bytes => _bytes;
}
