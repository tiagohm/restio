import 'package:restio/src/core/request/request_uri.dart';

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
