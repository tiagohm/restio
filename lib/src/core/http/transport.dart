import 'package:restio/src/common/closeable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Transport implements Closeable {
  Restio get client;

  Future<Response> send(Request request);

  Future<void> cancel();
}
