// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'retrofit.dart';

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

class _RestApi implements RestApi {
  _RestApi({Restio client, String baseUri})
      : client = client ?? Restio(),
        baseUri = baseUri ?? 'https://httpbin.org';

  final Restio client;

  final String baseUri;

  @override
  Future<String> getAsString() async {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = await _response.body.string();
    await _response.close();
    return _body;
  }

  @override
  Future<List<int>> getAsBytes() async {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = await _response.body.decompressed();
    await _response.close();
    return _body;
  }

  @override
  Future<List<int>> getAsRawBytes() async {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = await _response.body.raw();
    await _response.close();
    return _body;
  }

  @override
  Future<dynamic> getAsJson() async {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = await _response.body.json();
    await _response.close();
    return _body;
  }

  @override
  Stream<List<int>> getAsStream() async* {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = _response.body.data;
    yield* _body;
  }

  @override
  Future<Response> getAsResponse() async {
    final _request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = _response;
    return _body;
  }

  @override
  Future<Task> getTask(String id) async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/tasks/$id', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _json = await _response.body.json();
    final _body = Task.fromJson(_json);
    await _response.close();
    return _body;
  }

  @override
  Future<List<Task>> getTaskList() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/tasks', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _json = await _response.body.json();
    final _body = _json.map((item) => Task.fromJson(item));
    await _response.close();
    return _body;
  }

  @override
  Future<int> post() async {
    final _request = Request(
        method: 'POST', uri: RequestUri.parse('/post', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = _response.code;
    await _response.close();
    return _body;
  }

  @override
  Future<void> put() async {
    final _request =
        Request(method: 'PUT', uri: RequestUri.parse('/put', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> delete() async {
    final _request = Request(
        method: 'DELETE', uri: RequestUri.parse('/delete', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> patch() async {
    final _request = Request(
        method: 'PATCH', uri: RequestUri.parse('/patch', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> status(int code) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/status/$code', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<List<int>> bytes(int numberOfBytes) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/bytes/$numberOfBytes', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = await _response.body.decompressed();
    await _response.close();
    return _body;
  }

  @override
  Future<void> header0(String a, String b) async {
    final _headers = HeadersBuilder();
    _headers.add('a', '$a');
    _headers.add('B', '$b');
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _headers.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> header1(Map<String, dynamic> headers) async {
    final _headers = HeadersBuilder();
    _headers.addMap(headers);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _headers.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> header2(Headers headers) async {
    final _headers = HeadersBuilder();
    _headers.addItemList(headers);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _headers.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> header3(List<Header> headers) async {
    final _headers = HeadersBuilder();
    _headers.addAll(headers);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _headers.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> query0(String a, String b) async {
    final _queries = QueriesBuilder();
    _queries.add('a', '$a');
    _queries.add('B', '$b');
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _queries.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> query1(Map<String, dynamic> queries) async {
    final _queries = QueriesBuilder();
    _queries.addMap(queries);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _queries.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> query2(Queries queries) async {
    final _queries = QueriesBuilder();
    _queries.addItemList(queries);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _queries.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> query3({queries = const []}) async {
    final _queries = QueriesBuilder();
    _queries.addAll(queries);
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _queries.build());
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> stringAsBody(String body) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.string(body, contentType: MediaType.json));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> bytesAsBody(List<int> body) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.bytes(body, contentType: MediaType.json));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> streamAsBody(Stream<List<int>> body) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.stream(body, contentType: MediaType.json));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> fileAsBody(File body) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.file(body, contentType: MediaType.json));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> form0(String a, String b) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: FormBody(items: [FormItem('a', '$a'), FormItem('c', '$b')]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> form1(Map<String, dynamic> form) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: FormBody.fromMap(form));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> form2(FormBody form) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: form);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart0(String a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: [Part.form('a', '$a')]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart1(File b) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: [Part.fromFile('b', b, filename: null)]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart2(File b) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: [Part.fromFile('b', b, filename: 'b.txt')]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart3(File b) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: [
          Part.fromFile('b', b, filename: null, contentType: MediaType.json)
        ]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart4(Part b) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: [b]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart5(List<Part> a, Part b) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: [...a, b]));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart6(List<Part> a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(
            parts: [...a],
            contentType: MediaType.multipartMixed,
            boundary: '12345678'));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart7(List<Part> a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody(parts: a, contentType: MediaType.multipartMixed));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart8(Map<String, dynamic> a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: MultipartBody.fromMap(a, boundary: '12345678'));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> multipart9(MultipartBody a) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: a);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> extra(Map<String, dynamic> extra) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/get', baseUri: baseUri),
        extra: extra);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }

  @override
  Future<void> requestOptions(RequestOptions options) async {
    final _request = Request(
        method: 'GET',
        uri: RequestUri.parse('/get', baseUri: baseUri),
        options: options);
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
  }
}
