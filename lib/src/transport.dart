import 'package:restio/src/client.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

abstract class Transport {
  Restio get client;

  Future<Response> send(Request request);

  Future<void> cancel();

  Future<void> close();
}
