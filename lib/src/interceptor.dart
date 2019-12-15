import 'package:restio/src/chain.dart';
import 'package:restio/src/response.dart';

abstract class Interceptor {
  Future<Response> intercept(Chain chain);
}
