import 'package:restio/src/core/redirect/redirect.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

abstract class RedirectPolicy {
  bool apply(
    Response response,
    Request next,
    List<Redirect> redirects,
  );
}
