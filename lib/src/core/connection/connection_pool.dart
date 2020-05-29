import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/connection/connection.dart';
import 'package:restio/src/core/connection/connection_state.dart';
import 'package:restio/src/core/request/request.dart';

abstract class ConnectionPool<T> implements Closeable {
  final Duration idleTimeout;
  final _connectionStates = <String, ConnectionState<T>>{};
  var _closed = false;

  ConnectionPool({
    Duration idleTimeout,
  }) : idleTimeout = idleTimeout ?? defaultIdleTimeout {
    if (this.idleTimeout.isNegative || this.idleTimeout.inSeconds == 0) {
      throw ArgumentError.value(this.idleTimeout, 'idleTimeout');
    }
  }

  static const defaultIdleTimeout = Duration(minutes: 5);

  int get length => _connectionStates.length;

  Future<ConnectionState<T>> get(
    Restio restio,
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

    final client = await makeClient(restio, request);

    final connection = await makeConnection(
      request,
      client,
      ip,
    );

    _connectionStates[key] = await makeState(key, connection, () {
      _connectionStates.remove(key);
    });

    return _connectionStates[key];
  }

  Future<T> makeClient(Restio restio, Request request);

  Future<ConnectionState<T>> makeState(
    String key,
    Connection<T> connection,
    void Function() onTimeout,
  ) async {
    return ConnectionState(connection, idleTimeout, onTimeout: onTimeout);
  }

  Future<Connection<T>> makeConnection(
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
