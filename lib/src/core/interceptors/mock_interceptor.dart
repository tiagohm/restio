import 'package:restio/src/core/chain.dart';
import 'package:restio/src/core/interceptors/interceptor.dart';
import 'package:restio/src/core/response/response.dart';

class MockInterceptor implements Interceptor {
  final List<Response> responses;
  var _index = 0;

  MockInterceptor(this.responses) : assert(responses != null);

  @override
  Future<Response> intercept(Chain chain) async {
    if (_index < responses.length) {
      final response = responses[_index++];
      final now = DateTime.now();

      return response.copyWith(
        request: chain.request,
        sentAt: response.sentAt ?? now,
        receivedAt: response.receivedAt ?? now,
      );
    } else {
      throw StateError('This request has no response available');
    }
  }
}
