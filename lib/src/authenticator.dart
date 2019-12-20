import 'package:equatable/equatable.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

abstract class Authenticator extends Equatable {
  Future<Request> authenticate(Response response);
}
