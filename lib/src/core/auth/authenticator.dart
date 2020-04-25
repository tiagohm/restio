
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Authenticator {
  const Authenticator();

  Future<Request> authenticate(Response response);
}
