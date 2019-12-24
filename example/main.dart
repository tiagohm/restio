import 'package:restio/restio.dart';

final _client = Restio();

void main() async {
  final request = Request.get('https://api.ipify.org?format=json');
  final call = _client.newCall(request);
  final response = await call.execute();
  final dynamic data = await response.body.json();

  print(data['ip']);
}
