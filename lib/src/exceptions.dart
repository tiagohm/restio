class RestioException implements Exception {
  final String message;

  RestioException(this.message);
}

class TooManyRedirectsException extends RestioException {
  final Uri uri;

  TooManyRedirectsException(
    String message,
    this.uri,
  ) : super(message);
}

class TimedOutException extends RestioException {
  TimedOutException(String message) : super(message);
}

class CancelledException extends RestioException {
  CancelledException(String message) : super(message);
}
