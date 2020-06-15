// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

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
}
