import 'package:restio/restio.dart';

const client = Restio();

Future<void> main() async {
  final request = Request.get('https://api.ipify.org?format=json');
  final call = client.newCall(request);
  final response = await call.execute();
  final data = await response.body.json();
  await response.close();

  print(data['ip']);
}
