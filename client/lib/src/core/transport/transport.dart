import 'package:restio/src/core/call/cancellable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Transport {
  Restio get client;

  Future<Response> send(
    Request request, {
    Cancellable cancellable,
  });

  Future<void> cancel(String message);
}
