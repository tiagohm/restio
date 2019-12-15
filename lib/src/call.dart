import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

abstract class Call {
  Request get request;

  Future<Response> execute();

  void cancel(String message);

  bool get isExecuted;

  bool get isCancelled;
}
