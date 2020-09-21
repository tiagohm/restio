part of 'response.dart';

class ResponseBody implements Pauseable {
  final Stream<List<int>> data;
  final MediaType contentType;
  final int contentLength;
  final convert.Converter<List<int>, List<int>> decoder;

  const ResponseBody(
    this.data, {
    this.contentType,
    this.contentLength,
    this.decoder,
  });

  factory ResponseBody.bytes(
    List<int> data, {
    MediaType contentType,
    int contentLength = -1,
    convert.Converter<List<int>, List<int>> decompressor,
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
    convert.Converter<List<int>, List<int>> decompressor,
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
    convert.Converter<List<int>, List<int>> decompressor,
  }) {
    return ResponseBody(
      data,
      contentType: contentType,
      contentLength: contentLength,
      decoder: decompressor,
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

  /// Returns the raw response body data.
  Future<List<int>> raw() {
    return readStream(data);
  }

  /// Decompress response body data.
  Future<List<int>> decompressed() {
    return decoder == null ? raw() : readStream(data.transform(decoder));
  }

  /// Decodes response body data to [String].
  Future<String> string() async {
    final encoded = await decompressed();

    return contentType?.encoding != null
        ? contentType.encoding.decode(encoded)
        : convert.utf8.decode(encoded);
  }

  /// Decodes response body data to JSON.
  Future<dynamic> json() async {
    return convert.json.decode(await string());
  }

  /// Decodes response body data using [converter]
  /// or the default [Restio.bodyConverter].
  Future<T> decode<T>({
    BodyConverter converter,
  }) async {
    return (converter ?? Restio.bodyConverter)
        .decode<T>(await string(), contentType);
  }

  ResponseBody copyWith({
    Stream<List<int>> data,
    MediaType contentType,
    int contentLength,
    convert.Converter<List<int>, List<int>> decoder,
  }) {
    return ResponseBody(
      data ?? this.data,
      contentType: contentType ?? this.contentType,
      contentLength: contentLength ?? this.contentLength,
      decoder: decoder ?? this.decoder,
    );
  }

  @override
  String toString() {
    return 'ResponseBody { contentType: $contentType,'
        ' contentLength: $contentLength }';
  }
}
