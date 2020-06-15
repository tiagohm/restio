import 'package:restio/restio.dart';
import 'package:restio_cache/restio_cache.dart';

void main() async {
  final store = await LruCacheStore.local('./cache');
  final cache = Cache(store: store);
  final client = Restio(cache: cache);

  final request = get('https://postman-echo.com/get');
  final call = client.newCall(request);
  final response = await call.execute();

  final data = await response.body.json();
  print(data);

  await response.close();

  await client.close();
}
