import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio/retrofit.dart' as retrofit;

part 'retrofit.g.dart';

@retrofit.Api('https://httpbin.org')
abstract class RestApi {
  factory RestApi({Restio client, String baseUri}) = _RestApi;

  @retrofit.Get('/get')
  Future get();

  @retrofit.Post('/post')
  Future post();

  @retrofit.Put('/put')
  Future put();

  @retrofit.Delete('/delete')
  Future delete();

  @retrofit.Patch('/patch')
  Future patch();

  @retrofit.Get('/status/{code}')
  Future status(@retrofit.Path() int code);

  @retrofit.Get('/bytes/{n}')
  Future bytes(@retrofit.Path('n') int numberOfBytes);

  @retrofit.Post('/post/')
  Future header0(@retrofit.Header() String a, @retrofit.Header('B') String b);

  @retrofit.Post('/post/')
  Future header1(@retrofit.Headers() Map<String, dynamic> headers);

  @retrofit.Post('/post/')
  Future header2(@retrofit.Headers() Headers headers);

  @retrofit.Post('/post/')
  Future header3(@retrofit.Headers() List<Header> headers);

  @retrofit.Post('/post/')
  Future query0(@retrofit.Query() String a, @retrofit.Query('B') String b);

  @retrofit.Post('/post/')
  Future query1(@retrofit.Queries() Map<String, dynamic> queries);

  @retrofit.Post('/post/')
  Future query2(@retrofit.Queries() Queries queries);

  @retrofit.Post('/post/')
  Future query3({@retrofit.Queries() List<Query> queries = const []});

  @retrofit.Post('/post/')
  Future stringAsBody(@retrofit.Body('application/json') String body);

  @retrofit.Post('/post/')
  Future bytesAsBody(@retrofit.Body('application/json') List<int> body);

  @retrofit.Post('/post/')
  Future streamAsBody(
      @retrofit.Body('application/json') Stream<List<int>> body);

  @retrofit.Post('/post/')
  Future fileAsBody(@retrofit.Body('application/json') File body);

  @retrofit.Post('/post/')
  @retrofit.Form()
  Future form0(@retrofit.Field() String a, @retrofit.Field('c') String b);

  @retrofit.Post('/post/')
  @retrofit.Form()
  Future form1(@retrofit.Form() Map<String, dynamic> form);

  @retrofit.Post('/post/')
  @retrofit.Form()
  Future form2(@retrofit.Form() FormBody form);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart0(@retrofit.Part() String a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart1(@retrofit.Part() File b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart2(@retrofit.Part(filename: 'b.txt') File b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart3(@retrofit.Part(contentType: 'application/json') File b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart4(@retrofit.Part() Part b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart5(@retrofit.Part() List<Part> a, @retrofit.Part() Part b);

  @retrofit.Post('/post/')
  @retrofit.MultiPart(contentType: 'multipart/mixed', boundary: '12345678')
  Future multipart6(@retrofit.Part() List<Part> a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart7(
      @retrofit.MultiPart(contentType: 'multipart/mixed') List<Part> a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart(boundary: '12345678')
  Future multipart8(@retrofit.MultiPart() Map<String, dynamic> a);

  @retrofit.Post('/post/')
  @retrofit.MultiPart()
  Future multipart9(@retrofit.MultiPart() MultipartBody a);
}
