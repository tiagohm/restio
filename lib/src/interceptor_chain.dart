import 'package:restio/src/call.dart';
import 'package:restio/src/chain.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

class InterceptorChain implements Chain {
  @override
  final Call call;
  @override
  final Request request;
  final List<Interceptor> interceptors;
  final int index;

  InterceptorChain({
    this.interceptors,
    this.call,
    this.request,
    this.index,
  });

  @override
  Future<Response> proceed(Request request) async {
    final next = InterceptorChain(
      interceptors: interceptors,
      call: call,
      request: request,
      index: index + 1,
    );

    final interceptor = interceptors[index];

    final response = interceptor.intercept(next);

    return response;
  }
}
