import 'dart:convert';
import 'dart:io';

import 'package:restio/restio.dart';
import 'package:restio_retrofit/restio_retrofit.dart' as retrofit;

part 'httpbin.g.dart';

@retrofit.Api('https://httpbin.org')
@retrofit.Converter(Slideshow, SlideshowConverter)
abstract class HttpbinApi {
  factory HttpbinApi({Restio client, String baseUri}) = _HttpbinApi;

  @retrofit.Delete('/delete')
  Future<dynamic> delete();

  @retrofit.Get('/get')
  Future<dynamic> get();

  @retrofit.Patch('/patch')
  Future<dynamic> patch();

  @retrofit.Post('/post')
  Future<dynamic> post();

  @retrofit.Put('/put')
  Future<dynamic> put();

  @retrofit.Get('/basic-auth/{user}/{passwd}')
  Future<dynamic> basicAuth0(
    @retrofit.Path() @retrofit.BasicAuth.username() String user,
    @retrofit.Path('passwd') @retrofit.BasicAuth.password() String password,
  );

  @retrofit.Get('/basic-auth/restio/1234')
  @retrofit.BasicAuth('restio', '1234')
  Future<dynamic> basicAuth1();

  @retrofit.Get('/bearer')
  Future<dynamic> bearerAuth(@retrofit.Header() String authorization);

  @retrofit.Get('/digest-auth/auth/{user}/{passwd}/MD5')
  Future<dynamic> digestAuth0(
    @retrofit.Path() @retrofit.DigestAuth.username() String user,
    @retrofit.Path('passwd') @retrofit.DigestAuth.password() String password,
  );

  @retrofit.Get('/digest-auth/auth/restio/1234/MD5')
  @retrofit.DigestAuth('restio', '1234')
  Future<dynamic> digestAuth1();

  @retrofit.Get('/status/{code}')
  Future<int> status(@retrofit.Path() int code);

  @retrofit.Get('/status/400')
  Future<void> badRequest();

  @retrofit.Get('/status/200')
  @retrofit.Throws.only(200)
  Future<void> throwsOnOk();

  @retrofit.Get('/status/301')
  @retrofit.Throws.redirect()
  Future<void> throwsOnRedirect(RequestOptions options);

  @retrofit.Get('/status/400')
  @retrofit.Throws.clientError()
  Future<void> throwsOnClientError();

  @retrofit.Get('/status/500')
  @retrofit.Throws.serverError()
  Future<void> throwsOnServerError();

  @retrofit.Get('/status/400')
  Future<void> throwsOnNotSuccess();

  @retrofit.Get('/status/400')
  @retrofit.Throws.not(200)
  Future<void> throwsOnNotOk();

  @retrofit.Get('/headers')
  @retrofit.Header('a', '0')
  @retrofit.Header('b', '1')
  Future<dynamic> headers(
    @retrofit.Header() String c,
    @retrofit.Header('D') String d,
    @retrofit.Headers() Map<String, dynamic> e,
    @retrofit.Headers() Headers f,
    @retrofit.Headers() List<Header> g,
  );

  @retrofit.Get('/get?l=11')
  @retrofit.Query('a', '0')
  @retrofit.Query('b', '1')
  Future<dynamic> queries(
    @retrofit.Query() String c,
    @retrofit.Query('D') String d,
    @retrofit.Queries() Map<String, dynamic> e,
    @retrofit.Queries() Queries f,
    @retrofit.Queries() List<Query> g,
    @retrofit.Queries() List<String> h, // Query names.
  );

  @retrofit.Post('/post')
  @retrofit.Form()
  @retrofit.Field('a', '0')
  @retrofit.Field('b', '1')
  Future<dynamic> form(
    @retrofit.Field() String c,
    @retrofit.Field('D') String d,
    @retrofit.Form() Map<String, dynamic> e,
    @retrofit.Form() FormBody f,
    @retrofit.Form() List<Field> g,
  );

  @retrofit.Post('/post')
  @retrofit.Multipart()
  Future<dynamic> multipart(
    @retrofit.Part() String a,
    @retrofit.Part(name: 'B') String b,
    @retrofit.Part() File c,
    @retrofit.Part() Part d,
    @retrofit.Part() List<Part> e,
  );

  @retrofit.Post('/post')
  Future<dynamic> fileBody(@retrofit.Body(contentType: 'text/plain') File a);

  @retrofit.Post('/post')
  Future<dynamic> utf8StringBody(
      @retrofit.Body(contentType: 'text/plain') String a);

  @retrofit.Post('/post')
  Future<dynamic> asciiStringBody(
    @retrofit.Body(contentType: 'text/plain', charset: 'ascii') String a,
  );

  @retrofit.Post('/post')
  Future<dynamic> bytesBody(
      @retrofit.Body(contentType: 'text/plain') List<int> a);

  @retrofit.Post('/post')
  Future<dynamic> streamBody(
      @retrofit.Body(contentType: 'text/plain') Stream<List<int>> a);

  @retrofit.Post('/post')
  Future<dynamic> requestBody(@retrofit.Body() RequestBody a);

  @retrofit.Post('/post')
  Future<dynamic> slideshowBody(@retrofit.Body() Slideshow a);

  @retrofit.Get('/get')
  Future<Response> extra(@retrofit.Extra() Map<String, dynamic> a);

  @retrofit.Get('/json')
  Future<Slideshow> json();

  @retrofit.Get('/gzip')
  Future<List<int>> gzip();

  @retrofit.Get('/gzip')
  @retrofit.Raw()
  Future<List<int>> raw();
}

class Slideshow {
  final String author;
  final String date;
  final String title;

  const Slideshow(this.author, this.date, this.title);

  factory Slideshow.fromJson(dynamic data) {
    data = data['slideshow'];
    return Slideshow(data['author'], data['date'], data['title']);
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'date': date,
      'title': title,
    };
  }
}

class SlideshowConverter {
  static Future<String> encode(Slideshow data) async {
    return json.encode(data);
  }

  static Future<Slideshow> decode(String data) async {
    return Slideshow.fromJson(json.decode(data));
  }

  static Future<List<Slideshow>> decodeList(String data) async {
    return [for (final item in json.decode(data)) Slideshow.fromJson(item)];
  }
}
