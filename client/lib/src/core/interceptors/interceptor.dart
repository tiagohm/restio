import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Interceptor {
  Future<Response> intercept(Chain chain);
}
