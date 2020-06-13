import 'package:restio/restio.dart';

void main() async {
  final client = Restio();
  const options = RequestOptions(http2: true, allowServerPushes: true);
  final request = get('https://nghttp2.org/', options: options);
  final call = client.newCall(request);
  final response = await call.execute();

  await for (final push in response.pushes) {
    final headers = push.headers;
    final response = await push.response;

    print(headers);
    final data = await response.body.string();
    print(data);

    await response.close();
  }

  print(response.headers);
  final data = await response.body.string();
  print(data);

  await response.close();

  await client.close();
}
