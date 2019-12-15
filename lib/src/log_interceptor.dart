import 'package:restio/src/chain.dart';
import 'package:restio/src/interceptor.dart';
import 'package:restio/src/response.dart';

class LogInterceptor implements Interceptor {
  @override
  Future<Response> intercept(Chain chain) async {
    final request = chain.request;
    print('Sending request: $request');
    final response = await chain.proceed(chain.request);
    print('Received response: $response');
    return response;
  }
}
