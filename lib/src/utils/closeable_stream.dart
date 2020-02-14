import 'dart:async';

class CloseableStream<T> extends Stream<T> {
  StreamSubscription<T> _subscription;

  final Stream<T> stream;
  final void Function(T event) onData;
  final void Function() onDone;
  final Function onError;

  CloseableStream(
    this.stream, {
    this.onData,
    this.onDone,
    this.onError,
  });

  @override
  StreamSubscription<T> listen(
    void Function(T event) onData, {
    Function onError,
    void Function() onDone,
    bool cancelOnError,
  }) {
    assert(onData != null);

    void Function(T event) _onData;
    Function _onError;
    void Function() _onDone;

    if (this.onData != null && onData != null) {
      _onData = (event) {
        this.onData(event);
        onData(event);
      };
    } else {
      _onData = onData ?? this.onData;
    }

    if (this.onError != null && onError != null) {
      _onError = (e) {
        this.onError(e);
        onError(e);
      };
    } else {
      _onError = onError ?? this.onError;
    }

    if (this.onDone != null && onDone != null) {
      _onDone = () {
        this.onDone();
        onDone();
      };
    } else {
      _onDone = onDone ?? this.onDone;
    }

    try {
      final s = stream.listen(
        _onData,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: cancelOnError,
      );

      if (stream is! CloseableStream) {
        _subscription = s;
      }

      return s;
    } catch (e) {
      _onError(e);
      rethrow;
    }
  }

  Future close() async {
    if (stream is CloseableStream) {
      return (stream as CloseableStream).close();
    } else {
      return _subscription?.cancel();
    }
  }
}
