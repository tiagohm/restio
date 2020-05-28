import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/connection/connection_state.dart';
import 'package:restio/src/core/request/request.dart';

abstract class ConnectionPool<T> implements Closeable {
  final Restio client;
  final Duration idleTimeout;
  final _connectionStates = <String, ConnectionState<T>>{};
  var _closed = false;

  ConnectionPool(
    this.client, {
    Duration idleTimeout,
  }) : idleTimeout = idleTimeout ?? const Duration(seconds: 5 * 60) {
    if (this.idleTimeout.isNegative || this.idleTimeout.inSeconds == 0) {
      throw ArgumentError.value(this.idleTimeout, 'idleTimeout');
    }
  }

  int get length => _connectionStates.length;

  Future<ConnectionState<T>> get(
    Request request, [
    String ip,
  ]) async {
    final uri = request.uri;
    final key = Connection.makeKey(uri.scheme, uri.host, uri.effectivePort, ip);

    if (_connectionStates.containsKey(key)) {
      final state = _connectionStates[key];

      if (!state.isClosed) {
        return state;
      }
    }

    final client = makeClient(request);

    final connection = makeConnection(
      request,
      client,
      ip,
    );

    _connectionStates[key] =
        ConnectionState(connection, idleTimeout, onTimeout: () {
      _connectionStates.remove(key);
    });

    return _connectionStates[key];
  }

  T makeClient(Request request);

  Connection<T> makeConnection(
    Request request,
    T client, [
    String ip,
  ]);

  @override
  Future<void> close() async {
    if (isClosed) {
      return;
    }

    _closed = true;

    try {
      for (final state in _connectionStates.values) {
        await state.close();
      }
    } finally {
      _connectionStates.clear();
    }
  }

  @override
  bool get isClosed => _closed;
}
