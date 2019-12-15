import 'package:restio/src/call.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

abstract class Chain {
  Request get request;

  Call get call;

  Future<Response> proceed(Request request);
}
