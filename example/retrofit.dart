import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/retrofit.dart' as retrofit;

import 'task.dart';

part 'retrofit.g.dart';

@retrofit.Api('https://httpbin.org')
abstract class RestApi {
  factory RestApi({Restio client, String baseUri}) = _RestApi;

  @retrofit.Get('/get')
  Future<String> getAsString();

  @retrofit.Get('/get')
  Future<List<int>> getAsBytes();

  @retrofit.Get('/get')
  @retrofit.Raw()
  Future<List<int>> getAsRawBytes();

  @retrofit.Get('/get')
  Future<dynamic> getAsJson();

  @retrofit.Get('/get')
  Stream<List<int>> getAsStream();

  @retrofit.Get('/get')
  Future<Response> getAsResponse();

  @retrofit.Get('/tasks/{id}')
  Future<Task> getTask(@retrofit.Path() String id);

  @retrofit.Get('/tasks')
  Future<List<Task>> getTaskList();

  @retrofit.Post('/post')
  Future<int> post();

  @retrofit.Put('/put')
  Future<void> put();

  @retrofit.Delete('/delete')
  Future<void> delete();

  @retrofit.Patch('/patch')
  Future<void> patch();

  @retrofit.Get('/status/{code}')
  Future<void> status(@retrofit.Path() int code);

  @retrofit.Get('/bytes/{n}')
  Future<List<int>> bytes(@retrofit.Path('n') int numberOfBytes);

  @retrofit.Post('/post/')
  Future<void> header0(
      @retrofit.Header() String a, @retrofit.Header('B') String b);

  @retrofit.Post('/post/')
  Future<void> header1(@retrofit.Headers() Map<String, dynamic> headers);

  @retrofit.Post('/post/')
  Future<void> header2(@retrofit.Headers() Headers headers);

  @retrofit.Post('/post/')
  Future<void> header3(@retrofit.Headers() List<Header> headers);

  @retrofit.Post('/post/')
  Future<void> query0(
      @retrofit.Query() String a, @retrofit.Query('B') String b);

  @retrofit.Post('/post/')
  Future<void> query1(@retrofit.Queries() Map<String, dynamic> queries);

  @retrofit.Post('/post/')
  Future<void> query2(@retrofit.Queries() Queries queries);

  @retrofit.Post('/post/')
  Future<void> query3({@retrofit.Queries() List<Query> queries = const []});

  @retrofit.Post('/post/')
  Future<void> stringAsBody(@retrofit.Body('application/json') String body);

  @retrofit.Post('/post/')
  Future<void> bytesAsBody(@retrofit.Body('application/json') List<int> body);

  @retrofit.Post('/post/')
  Future<void> streamAsBody(
      @retrofit.Body('application/json') Stream<List<int>> body);

  @retrofit.Post('/post/')
  Future<void> fileAsBody(@retrofit.Body('application/json') File body);

  @retrofit.Post('/post/')
  @retrofit.Form()
  Future<void> form0(@retrofit.Field() String a, @retrofit.Field('c') String b);

  @retrofit.Post('/post/')
  @retrofit.Form()
  Future<void> form1(@retrofit.Form() Map<String, dynamic> form);

  @retrofit.Post('/post/')
  @retrofit.Form()
  Future<void> form2(@retrofit.Form() FormBody form);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart0(@retrofit.Part() String a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart1(@retrofit.Part() File b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart2(@retrofit.Part(filename: 'b.txt') File b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart3(
      @retrofit.Part(contentType: 'application/json') File b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart4(@retrofit.Part() Part b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart5(
      @retrofit.Part() List<Part> a, @retrofit.Part() Part b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart(contentType: 'multipart/mixed', boundary: '12345678')
  Future<void> multipart6(@retrofit.Part() List<Part> a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart7(
      @retrofit.MultiPart(contentType: 'multipart/mixed') List<Part> a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart(boundary: '12345678')
  Future<void> multipart8(@retrofit.MultiPart() Map<String, dynamic> a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future<void> multipart9(@retrofit.MultiPart() MultipartBody a);

  @retrofit.Get('/get')
  Future<void> extra(@retrofit.Extra() Map<String, dynamic> extra);

  @retrofit.Get('/get')
  Future<void> requestOptions(RequestOptions options);
}
