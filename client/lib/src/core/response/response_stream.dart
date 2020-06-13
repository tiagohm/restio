import 'dart:async';

import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/common/pausable.dart';

class ResponseStream extends Stream<List<int>> implements Closeable, Pauseable {
  StreamSubscription<List<int>> _subscription;
  var _isPaused = false;
  var _isClosed = false;

  final Stream<List<int>> stream;
  final void Function(List<int> event) onData;
  final void Function() onDone;
  final Function onError;
  final FutureOr<void> Function() onClose;

  ResponseStream(
    this.stream, {
    this.onData,
    this.onDone,
    this.onError,
    this.onClose,
  });

  @override
  Future<E> drain<E>([E futureValue]) {
    return stream.drain(futureValue);
  }

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event) onData, {
    Function onError,
    void Function() onDone,
    bool cancelOnError,
  }) {
    assert(onData != null);

    void Function(List<int> event) _onData;
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
      _onError = (e, stackTrace) {
        this.onError(e, stackTrace);
        onError(e, stackTrace);
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

      if (stream is! Closeable) {
        _subscription = s;
      }

      return s;
    } catch (e, stackTrace) {
      _onError?.call(e, stackTrace);
      rethrow;
    }
  }

  @override
  void pause() {
    if (!_isPaused) {
      _isPaused = true;
      _subscription?.pause();
    }
  }

  @override
  void resume() {
    if (_isPaused) {
      _subscription?.resume();
      _isPaused = false;
    }
  }

  @override
  bool get isPaused => _isPaused;

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    _isClosed = true;

    if (_subscription != null) {
      await _subscription.cancel();
      _subscription = null;
    }

    if (stream is Closeable) {
      await (stream as Closeable).close();
    }

    await onClose?.call();
  }

  @override
  bool get isClosed => _isClosed;
}
