import 'package:restio/src/core/request/request_uri.dart';
import 'package:restio/src/core/response/response.dart';

class RestioException implements Exception {
  final String message;

  const RestioException(this.message);

  @override
  String toString() => message;
}

class TooManyRedirectsException extends RestioException {
  final RequestUri uri;

  const TooManyRedirectsException(
    String message,
    this.uri,
  ) : super(message);
}

class TimedOutException extends RestioException {
  const TimedOutException(String message) : super(message);
}

class CancelledException extends RestioException {
  const CancelledException(String message) : super(message);
}

class TooManyRetriesException extends RestioException {
  const TooManyRetriesException(String message) : super(message);
}

class HttpStatusException extends RestioException {
  final int code;
  final Response response;

  HttpStatusException(this.response)
      : assert(response != null),
        code = response.code,
        super('${response.code} ${response.message}');

  static void throws(Response response) {
    throw HttpStatusException(response);
  }

  static void throwsIfNotSuccess(Response response) {
    if (!response.isSuccess) {
      throws(response);
    }
  }

  static void throwsIfBetween(
    Response response,
    int min,
    int max, {
    bool negate = false,
  }) {
    if (negate ^ (response.code >= min && response.code < max)) {
      throws(response);
    }
  }
}
