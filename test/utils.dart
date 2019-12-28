import 'package:restio/src/client.dart';
import 'package:restio/src/request.dart';
import 'package:restio/src/response.dart';

Future<Response> requestResponse(Restio client, Request request) async {
  final call = client.newCall(request);
  return call.execute();
}

Future<String> obtainResponseBodyAsString(Response response) async {
  return response.body.string();
}

Future<String> requestString(Restio client, Request request) async {
  final response = await requestResponse(client, request);
  return obtainResponseBodyAsString(response);
}

Future<dynamic> requestJson(Restio client, Request request) async {
  final response = await requestResponse(client, request);
  return response.body.json();
}
