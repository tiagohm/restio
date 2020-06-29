// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'jsonplaceholder.dart';

// **************************************************************************
// RetrofitGenerator
// **************************************************************************

class _JsonplaceholderApi implements JsonplaceholderApi {
  _JsonplaceholderApi({Restio client, String baseUri})
      : client = client ?? Restio(),
        baseUri = baseUri ?? 'https://jsonplaceholder.typicode.com/';

  final Restio client;

  final String baseUri;

  @override
  Future<List<User>> getUsers() async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/users', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.decode<List<User>>();
    await _response.close();
    return _body;
  }

  @override
  Future<User> getUser(int id) async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/users/$id', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.decode<User>();
    await _response.close();
    return _body;
  }

  @override
  Future<Result<User>> getUserWithResult(int id) async {
    final _request = Request(
        method: 'GET', uri: RequestUri.parse('/users/$id', baseUri: baseUri));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    final _body = await _response.body.decode<User>();
    await _response.close();
    return Result(
        data: _body,
        code: _response.code,
        message: _response.message,
        cookies: _response.cookies,
        headers: _response.headers);
  }

  @override
  Future<dynamic> createUser(User user) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/users', baseUri: baseUri),
        body: RequestBody.encode<User>(user, contentType: MediaType.json));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    HttpStatusException.throwsIfNotSuccess(_response);
    final _body = await _response.body.decode<dynamic>();
    await _response.close();
    return _body;
  }

  @override
  Future<Result<void>> createUserWithResult(User user) async {
    final _request = Request(
        method: 'POST',
        uri: RequestUri.parse('/users', baseUri: baseUri),
        body: RequestBody.encode<User>(user, contentType: MediaType.json));
    final _call = client.newCall(_request);
    final _response = await _call.execute();
    await _response.close();
    return Result(
        data: null,
        code: _response.code,
        message: _response.message,
        cookies: _response.cookies,
        headers: _response.headers);
  }
}
