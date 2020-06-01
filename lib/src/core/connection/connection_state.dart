import 'dart:async';

import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/connection/connection.dart';

class ConnectionState implements Closeable {
  final Connection connection;
  final void Function() onTimeout;
  Duration _timeout;
  Timer _timer;
  var _idle = false;

  ConnectionState(
    this.connection,
    Duration timeout, {
    this.onTimeout,
  }) : _timeout = timeout;

  void start() {
    if (isClosed) {
      throw StateError('Connection is closed');
    }

    _idle = true;
    _timer?.cancel();

    _timer = Timer(timeout, () async {
      await close();
      onTimeout?.call();
    });

    _timer.tick;
  }

  void stop() {
    _idle = false;
    _timer?.cancel();
    _timer = null;
  }

  void restart() {
    stop();
    start();
  }

  @override
  Future<void> close() async {
    stop();

    await connection.close();
  }

  Duration get timeout => _timeout;

  set timeout(Duration value) {
    _timeout = value;

    if (!isClosed) {
      restart();
    }
  }

  @override
  bool get isClosed => connection.isClosed;

  bool get isIdle => _idle;
}
