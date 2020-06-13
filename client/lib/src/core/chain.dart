import 'package:restio/src/core/call/call.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Chain {
  Request get request;

  Call get call;

  Future<Response> proceed(Request request);
}
