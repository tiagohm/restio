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
  final List<Interceptor> _interceptors;
  final int _index;

  const InterceptorChain({
    List<Interceptor> interceptors,
    this.call,
    this.request,
    int index,
  })  : _interceptors = interceptors,
        _index = index;

  @override
  Future<Response> proceed(Request request) async {
    final next = InterceptorChain(
      interceptors: _interceptors,
      call: call,
      request: request,
      index: _index + 1,
    );

    final interceptor = _interceptors[_index];

    final response = interceptor.intercept(next);

    return response;
  }
}
