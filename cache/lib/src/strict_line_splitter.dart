import 'dart:async';
import 'dart:convert';

class StrictLineSplitter extends StreamTransformerBase<String, String> {
  final bool includeUnterminatedLine;

  var _hasUnterminatedLine = false;

  StrictLineSplitter({
    this.includeUnterminatedLine = true,
  });

  StringConversionSink startChunkedConversion(Sink<String> sink) {
    return _StrictLineSplitterSink(
      sink is StringConversionSink ? sink : StringConversionSink.from(sink),
      onUnterminatedLine: () => _hasUnterminatedLine = true,
      includeUnterminatedLine: includeUnterminatedLine,
    );
  }

  bool get hasUnterminatedLine => _hasUnterminatedLine;

  @override
  Stream<String> bind(Stream<String> stream) {
    return Stream<String>.eventTransformed(
      stream,
      (sink) => _StrictLineSplitterEventSink(
        sink,
        onUnterminatedLine: () => _hasUnterminatedLine = true,
        includeUnterminatedLine: includeUnterminatedLine,
      ),
    );
  }
}

class _StrictLineSplitterSink extends StringConversionSinkBase {
  final StringConversionSink _sink;
  final void Function() onUnterminatedLine;
  final bool includeUnterminatedLine;

  _StrictLineSplitterSink(
    this._sink, {
    this.onUnterminatedLine,
    this.includeUnterminatedLine,
  });

  @override
  void addSlice(
    String str,
    int start,
    int end,
    bool isLast,
  ) {
    if (start >= end) {
      if (isLast) close();
      return;
    }

    var pos = start;

    for (var i = start; i < end; i++) {
      final c = str.codeUnitAt(i);

      if (c == 0x0A) {
        final lineEnd =
            (i > start && str.codeUnitAt(i - 1) == 0x0D) ? i - 1 : i;
        _sink.add(str.substring(pos, lineEnd));
        pos = i + 1;
      }
    }

    if (pos != end) {
      if (includeUnterminatedLine) {
        final lineEnd = (str.codeUnitAt(end - 1) == 0x0D) ? end - 1 : end;
        _sink.add(str.substring(pos, lineEnd));
      }

      onUnterminatedLine?.call();
    }

    if (isLast) {
      close();
    }
  }

  @override
  void close() {
    _sink.close();
  }
}

class _StrictLineSplitterEventSink extends _StrictLineSplitterSink
    implements EventSink<String> {
  final EventSink<String> _eventSink;

  _StrictLineSplitterEventSink(
    EventSink<String> sink, {
    void Function() onUnterminatedLine,
    bool includeUnterminatedLine,
  })  : _eventSink = sink,
        super(
          StringConversionSink.from(sink),
          onUnterminatedLine: onUnterminatedLine,
          includeUnterminatedLine: includeUnterminatedLine,
        );

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    _eventSink.addError(error, stackTrace);
  }
}
