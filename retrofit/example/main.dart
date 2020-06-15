import 'package:restio/restio.dart';
import 'package:restio_retrofit/restio_retrofit.dart' as retrofit;

part 'main.g.dart';

void main() async {
  final client = Restio();
  final api = HttpbinApi(client: client);

  final data = api.get();
  print(data);

  await client.close();
}

@retrofit.Api('https://httpbin.org')
abstract class HttpbinApi {
  factory HttpbinApi({Restio client, String baseUri}) = _HttpbinApi;

  @retrofit.Get('/get')
  Future<dynamic> get();
}
