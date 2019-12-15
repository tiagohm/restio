import 'package:restio/restio.dart';

final client = Restio();

void main() async {
  final request = Request.get('https://api.ipify.org?format=json');
  final call = client.newCall(request);
  final response = await call.execute();
  final dynamic data = await response.body.json();

  print(data['ip']);
}
