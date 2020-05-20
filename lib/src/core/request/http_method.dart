class HttpMethod {
  HttpMethod._();

  static const get = 'GET';
  static const post = 'POST';
  static const put = 'PUT';
  static const delete = 'DELETE';
  static const head = 'HEAD';
  static const patch = 'PATCH';
  static const options = 'OPTIONS';
  static const move = 'MOVE';
  static const trace = 'TRACE';

  static bool invalidatesCache(String method) =>
      method == post ||
      method == patch ||
      method == put ||
      method == delete ||
      method == move;

  static bool requiresRequestBody(String method) =>
      method == 'POST' ||
      method == 'PUT' ||
      method == 'PATCH' ||
      method == 'PROPPATCH' ||
      method == 'REPORT';

  static bool permitsRequestBody(String method) =>
      method != 'GET' && method != 'HEAD';

  static bool redirectsWithBody(String method) => method == 'PROPFIND';

  static bool redirectsToGet(String method) => method != 'PROPFIND';
}
