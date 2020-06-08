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
  Future query3(@retrofit.Queries() List<Query> queries);

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
}
