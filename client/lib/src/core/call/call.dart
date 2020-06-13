import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Call {
  Request get request;

  Future<Response> execute();

  void cancel(String message);

  bool get isExecuting;

  bool get isCancelled;
}
