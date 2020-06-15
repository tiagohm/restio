// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'httpbin.dart';

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

class _HttpbinApi implements HttpbinApi {
  _HttpbinApi({Restio client, String baseUri})
      : client = client ?? Restio(),
        baseUri = baseUri ?? 'https://httpbin.org';

  final Restio client;

  final String baseUri;

  @override
  Future<dynamic> delete() async {
    final _request = Request(
        method: 'DELETE', uri: RequestUri.parse('/delete', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> get() async {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> patch() async {
    final _request = Request(
        method: 'PATCH', uri: RequestUri.parse('/patch', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> post() async {
    final _request = Request(
        method: 'POST', uri: RequestUri.parse('/post', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> put() async {
    final _request =
        Request(method: 'PUT', uri: RequestUri.parse('/put', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> basicAuth0(String user, String password) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/basic-auth/$user/$password', baseUri: baseUri),
        options: RequestOptions(
            auth: BasicAuthenticator(username: user, password: password)));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> basicAuth1() async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/basic-auth/restio/1234', baseUri: baseUri),
        options: const RequestOptions(
            auth: BasicAuthenticator(username: 'restio', password: '1234')));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> bearerAuth(String authorization) async {
    final _headers = HeadersBuilder();
    _headers.add('authorization', '$authorization');
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/bearer', baseUri: baseUri),
        headers: _headers.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> digestAuth0(String user, String password) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/digest-auth/auth/$user/$password/MD5',
            baseUri: baseUri),
        options: RequestOptions(
            auth: DigestAuthenticator(username: user, password: password)));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> digestAuth1() async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/digest-auth/auth/restio/1234/MD5',
            baseUri: baseUri),
        options: const RequestOptions(
            auth: DigestAuthenticator(username: 'restio', password: '1234')));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<int> status(int code) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/status/$code', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = _response.code;
    await _response.close();
    return _body;
  }

  @override
  Future<void> badRequest() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/status/400', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    await _response.close();
  }

  @override
  Future<void> throwsOnOk() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/status/200', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfBetween(_response, 200, 201);
    await _response.close();
  }

  @override
  Future<void> throwsOnRedirect(RequestOptions options) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/status/301', baseUri: baseUri),
        options: options);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfBetween(_response, 300, 400);
    await _response.close();
  }

  @override
  Future<void> throwsOnClientError() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/status/400', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfBetween(_response, 400, 500);
    await _response.close();
  }

  @override
  Future<void> throwsOnServerError() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/status/500', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfBetween(_response, 500, 600);
    await _response.close();
  }

  @override
  Future<void> throwsOnNotSuccess() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/status/400', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    await _response.close();
  }

  @override
  Future<void> throwsOnNotOk() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/status/400', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfBetween(_response, 200, 201, negate: true);
    await _response.close();
  }

  @override
  Future<dynamic> headers(String c, String d, Map<String, dynamic> e, Headers f,
      List<Header> g) async {
    final _headers = HeadersBuilder();
    _headers.add('a', '0');
    _headers.add('b', '1');
    _headers.add('c', '$c');
    _headers.add('D', '$d');
    _headers.addMap(e);
    _headers.addItemList(f);
    _headers.addAll(g);
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/headers', baseUri: baseUri),
        headers: _headers.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> queries(String c, String d, Map<String, dynamic> e, Queries f,
      List<Query> g, List<String> h) async {
    final _queries = QueriesBuilder();
    _queries.add('a', '0');
    _queries.add('b', '1');
    _queries.add('c', '$c');
    _queries.add('D', '$d');
    _queries.addMap(e);
    _queries.addItemList(f);
    _queries.addAll(g);
    // ignore: avoid_function_literals_in_foreach_calls
    h?.forEach((item) => _queries.add(item, null));
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/get?l=11', baseUri: baseUri),
        queries: _queries.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> form(String c, String d, Map<String, dynamic> e, FormBody f,
      List<Field> g) async {
    final _form = FormBuilder();
    _form.add('a', '0');
    _form.add('b', '1');
    _form.add('c', '$c');
    _form.add('D', '$d');
    _form.addMap(e);
    _form.addItemList(f);
    _form.addAll(g);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: _form.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> multipart(
      String a, String b, File c, Part d, List<Part> e) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: MultipartBody(parts: [
          Part.form('a', '$a'),
          Part.form('B', '$b'),
          Part.fromFile('c', c, filename: null),
          d,
          ...e
        ]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> fileBody(File a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: RequestBody.file(a, contentType: MediaType.text));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> utf8StringBody(String a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: RequestBody.string(a, contentType: MediaType.text));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> asciiStringBody(String a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: RequestBody.string(a,
            contentType: MediaType.text, charset: 'ascii'));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> bytesBody(List<int> a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: RequestBody.bytes(a, contentType: MediaType.text));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> streamBody(Stream<List<int>> a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: RequestBody.stream(a, contentType: MediaType.text));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> requestBody(RequestBody a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: a);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> slideshowBody(Slideshow a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post', baseUri: baseUri),
        body: RequestBody.string(await SlideshowConverter.encode(a)));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Future<Response> extra(Map<String, dynamic> a) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/get', baseUri: baseUri),
        extra: a);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = _response;
    return _body;
  }

  @override
  Future<Slideshow> json() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/json', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _data = await _response.body.string();
    final _body = await SlideshowConverter.decode(_data);
    await _response.close();
    return _body;
  }

  @override
  Future<List<int>> gzip() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/gzip', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.decompressed();
    await _response.close();
    return _body;
  }

  @override
  Future<List<int>> raw() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/gzip', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.raw();
    await _response.close();
    return _body;
  }
}
