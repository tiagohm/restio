part of 'response.dart';

class ResponseBody implements Pauseable {
  final Stream<List<int>> data;
  final MediaType contentType;
  final int contentLength;
  final Decompressor decompressor;

  const ResponseBody(
    this.data, {
    this.contentType,
    this.contentLength,
    this.decompressor,
  });

  factory ResponseBody.bytes(
    List<int> data, {
    MediaType contentType,
    int contentLength = -1,
    Decompressor decompressor,
  }) {
    return ResponseBody.stream(
      Stream.fromIterable([data]),
      contentType: contentType,
      contentLength: contentLength == -1 ? data.length : contentLength,
      decompressor: decompressor,
    );
  }

  factory ResponseBody.string(
    String text, {
    MediaType contentType,
    int contentLength = -1,
    Decompressor decompressor,
  }) {
    final encoding = contentType?.encoding ?? convert.utf8;
    return ResponseBody.stream(
      Stream.fromFuture(Future(() => encoding.encode(text))),
      contentType: contentType,
      contentLength: contentLength,
      decompressor: decompressor,
    );
  }

  factory ResponseBody.stream(
    Stream<List<int>> data, {
    MediaType contentType,
    int contentLength = -1,
    Decompressor decompressor,
  }) {
    return ResponseBody(
      data,
      contentType: contentType,
      contentLength: contentLength,
      decompressor: decompressor,
    );
  }

  factory ResponseBody.empty() {
    return ResponseBody.bytes(
      const <int>[],
      contentLength: 0,
      contentType: MediaType.octetStream,
    );
  }

  @override
  void pause() {
    if (data is Pauseable) {
      (data as Pauseable).pause();
    }
  }

  @override
  void resume() {
    if (data is Pauseable) {
      (data as Pauseable).resume();
    }
  }

  @override
  bool get isPaused => data is Pauseable && (data as Pauseable).isPaused;

  Future<void> drain() async {
    await data.drain();
  }

  Future<List<int>> raw() {
    return readStream(
        data.transform(Decompressor(null, decompressor?.onChunkReceived)));
  }

  Future<List<int>> decompressed() {
    return decompressor == null
        ? raw()
        : readStream(data.transform(decompressor));
  }

  Future<String> string() async {
    final encoded = await decompressed();

    return contentType?.encoding != null
        ? contentType.encoding.decode(encoded)
        : convert.utf8.decode(encoded);
  }

  // TODO: Criar um JsonAdapter para usar o compute do Flutter.
  Future<dynamic> json() async {
    return convert.json.decode(await string());
  }

  ResponseBody copyWith({
    Stream<List<int>> data,
    MediaType contentType,
    int contentLength,
    Decompressor decompressor,
  }) {
    return ResponseBody(
      data ?? this.data,
      contentType: contentType ?? this.contentType,
      contentLength: contentLength ?? this.contentLength,
      decompressor: decompressor ?? this.decompressor,
    );
  }

  @override
  String toString() {
    return 'ResponseBody { contentType: $contentType,'
        ' contentLength: $contentLength }';
  }
}
