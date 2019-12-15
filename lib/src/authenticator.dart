import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

abstract class Authenticator {
  Future<Request> authenticate(Response response);
}
