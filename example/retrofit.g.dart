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
  get() async {
    final request =
        Request(method: 'GET', uri: RequestUri.parse('/get', baseUri: baseUri));
  }

  @override
  post() async {
    final request = Request(
        method: 'POST', uri: RequestUri.parse('/post', baseUri: baseUri));
  }

  @override
  put() async {
    final request =
        Request(method: 'PUT', uri: RequestUri.parse('/put', baseUri: baseUri));
  }

  @override
  delete() async {
    final request = Request(
        method: 'DELETE', uri: RequestUri.parse('/delete', baseUri: baseUri));
  }

  @override
  patch() async {
    final request = Request(
        method: 'PATCH', uri: RequestUri.parse('/patch', baseUri: baseUri));
  }

  @override
  status(int code) async {
    final request = Request(
        method: 'GET',
        uri: RequestUri.parse('/status/$code', baseUri: baseUri));
  }

  @override
  bytes(int numberOfBytes) async {
    final request = Request(
        method: 'GET',
        uri: RequestUri.parse('/bytes/$numberOfBytes', baseUri: baseUri));
  }

  @override
  header0(String a, String b) async {
    final _hb = HeadersBuilder();
    _hb.add('a', '$a');
    _hb.add('B', '$b');
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _hb.build());
  }

  @override
  header1(Map<String, dynamic> headers) async {
    final _hb = HeadersBuilder();
    _hb.addMap(headers);
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _hb.build());
  }

  @override
  header2(Headers headers) async {
    final _hb = HeadersBuilder();
    _hb.addItemList(headers);
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _hb.build());
  }

  @override
  header3(List<Header> headers) async {
    final _hb = HeadersBuilder();
    _hb.addAll(headers);
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        headers: _hb.build());
  }

  @override
  query0(String a, String b) async {
    final _qb = QueriesBuilder();
    _qb.add('a', '$a');
    _qb.add('B', '$b');
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _qb.build());
  }

  @override
  query1(Map<String, dynamic> queries) async {
    final _qb = QueriesBuilder();
    _qb.addMap(queries);
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _qb.build());
  }

  @override
  query2(Queries queries) async {
    final _qb = QueriesBuilder();
    _qb.addItemList(queries);
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _qb.build());
  }

  @override
  query3(List<Query> queries) async {
    final _qb = QueriesBuilder();
    _qb.addAll(queries);
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        queries: _qb.build());
  }

  @override
  stringAsBody(String body) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.string(body, contentType: MediaType.json));
  }

  @override
  bytesAsBody(List<int> body) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.bytes(body, contentType: MediaType.json));
  }

  @override
  streamAsBody(Stream<List<int>> body) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.stream(body, contentType: MediaType.json));
  }

  @override
  fileAsBody(File body) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: RequestBody.file(body, contentType: MediaType.json));
  }

  @override
  form0(String a, String b) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: FormBody(items: [FormItem('a', '$a'), FormItem('c', '$b')]));
  }

  @override
  form1(Map<String, dynamic> form) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: FormBody.fromMap(form));
  }

  @override
  form2(FormBody form) async {
    final request = Request(
        method: 'POST',
        uri: RequestUri.parse('/post/', baseUri: baseUri),
        body: form);
  }
}
