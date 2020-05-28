import 'dart:io';

import 'package:meta/meta.dart';
import 'package:restio/src/core/connection/connection.dart';

class HttpConnection extends Connection<HttpClient> {
  var _isClosed = false;

  HttpConnection({
    @required String scheme,
    @required String host,
    @required int port,
    String ip,
    @required HttpClient client,
  }) : super(scheme: scheme, host: host, port: port, ip: ip, client: client);

  @override
  Future<void> close() async {
    if (!isClosed) {
      _isClosed = true;
      client.close();
    }
  }

  @override
  bool get isClosed => _isClosed;
}
