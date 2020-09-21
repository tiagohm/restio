import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class Authenticator {
  const Authenticator();

  bool get noRedirect;

  Future<Request> authenticate(Response response);

  Future<Request> authenticateNoRedirect(Request request);
}
