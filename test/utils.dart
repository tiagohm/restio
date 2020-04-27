import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/request/request.dart';
import 'package:restio/src/core/response/response.dart';

Future<Response> requestResponse(Restio client, Request request) async {
  final call = client.newCall(request);
  return call.execute();
}

Future<String> obtainResponseBodyAsString(Response response) async {
  try {
    return await response.body.string();
  } finally {
    await response.close();
  }
}

Future<String> requestString(Restio client, Request request) async {
  final response = await requestResponse(client, request);
  return obtainResponseBodyAsString(response);
}

Future<dynamic> requestJson(Restio client, Request request) async {
  final response = await requestResponse(client, request);
  try {
    return await response.body.json();
  } finally {
    await response.close();
  }
}
