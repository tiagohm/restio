@Timeout(Duration(hours: 1))

import 'package:restio/restio.dart';
import 'package:restio/src/cache/cache_control.dart';
import 'package:test/test.dart';

void main() {
  final client = Restio(
    interceptors: [
      LogInterceptor(),
    ],
  );

  test('E-Tag', () async {
    final cache = Cache(store: MemoryCacheStore());
    final cacheClient = client.copyWith(cache: cache);

    final request = Request.get(
      'https://postman-echo.com/get',
    );

    var call = cacheClient.newCall(request);
    var response = await call.execute();
    print(await response.body.data.string());

    expect(response.code, 200);
    expect(cache.requestCount, 1);
    expect(cache.hitCount, 0);
    expect(cache.networkCount, 1);

    call = cacheClient.newCall(request);
    response = await call.execute();
    print(await response.body.data.string());

    expect(response.code, 200);
    expect(cache.requestCount, 2);
    expect(cache.hitCount, 0);
    expect(cache.networkCount, 2);

    call = cacheClient.newCall(request.copyWith(
      cacheControl: CacheControl.forceCache,
    ));
    response = await call.execute();
    print(await response.body.data.string());

    expect(response.code, 200);
    expect(response.spentMilliseconds, 0);
    expect(cache.requestCount, 3);
    expect(cache.hitCount, 1);
    expect(cache.networkCount, 2);
  });
}
