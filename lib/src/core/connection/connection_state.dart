import 'dart:async';

import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/connection/connection.dart';

class ConnectionState implements Closeable {
  final Connection connection;
  final Duration timeout;
  Timer _timer;
  final void Function() onTimeout;

  ConnectionState(
    this.connection,
    this.timeout, {
    this.onTimeout,
  });

  void start() {
    _timer?.cancel();

    _timer = Timer(timeout, () async {
      await close();
      onTimeout?.call();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() async {
    stop();

    await connection.close();
  }

  @override
  bool get isClosed => connection.isClosed;
}
