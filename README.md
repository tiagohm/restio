# Restio

An HTTP Client for Dart inpired by [OkHttp](http://square.github.io/okhttp/).

## Features

* GET, POST, PUT, DELETE, HEAD, PATCH, OPTIONS, etc.
* Request Body can be List&lt;int&gt;, String, Stream, File or JSON Object.
  * Auto detects Content-Type.
  * Buffer less processing for List&lt;int&gt; and File.
* Response Body gives you access as raw or decompressed data (List&lt;int&gt;), String and JSON Object too.
  * Supports Gzip, Deflate and Brotli.
* Easy to upload one or more file(s) via multipart/form-data.
  * Auto detects file content type.
* Interceptors using [Chain of responsibility](https://en.wikipedia.org/wiki/Chain-of-responsibility_pattern).
* Basic, Digest, Bearer and Hawk authorization methods.
* Send and save cookies for your request via CookieJar.
* Allows GET request with payload.
* Works fine with `HTTP/2` and `HTTP/1.1`.
* HTTP/2 Server Push support.
* Have Client level options and also override at Request level if you want to.
* Caching applying [RFC 7234](https://tools.ietf.org/html/rfc7234) and Lru Replacement Strategy.
   * Supports encryption.
* Custom Client Certificates.
* Proxy settings.
* DNS-over-UDP and DNS-over-HTTPS.
* WebSocket and SSE.
* Redirect Policy.

## Installation

In `pubspec.yaml` add the following dependency:

```yaml
dependencies:
  restio: ^0.7.1
```

## How to use

1. Create a instance of `Restio`:
```dart
final client = Restio();
```

2. Create a `Request`:
```dart
final request = Request(
    uri: RequestUri.parse('https://httpbin.org/get'),
    method: HttpMethod.get,
);
```

or

```dart
final request = Request.get('https://httpbin.org/get');
```

or

```dart
final request = get('https://httpbin.org/get');
```

3. Create a `Call` from `Request`:
```dart
final call = client.newCall(request);
```

4. Execute the `Call` and get a `Response`:
```dart
final response = await call.execute();
```

5. At end close the response.
```dart
await response.close();
```

6. To close all persistent connections:
```dart
await client.close();
```

## Recipes

### Request Options

```dart
final options = RequestOptions(
  connectTimeout : Duration(...),  // default is null (no timeout)
  writeTimeout : Duration(...),  // default is null (no timeout)
  receiveTimeout : Duration(...),  // default is null (no timeout)
  auth: BasicAuthenticator(...), // default is null (no auth)
  followRedirects: true,
  maxRedirects: 5,
  verifySSLCertificate: false,
  userAgent: 'Restio/0.7.1',
  proxy: Proxy(...), // default is null
  dns: DnsOverHttps(...), // default is null
);

// At Client level.
final client = Restio(options: options);

// Override at Request Level.
final request = get('http://httpbin.org/get', options: options);
```

### Adding Headers and Queries

```dart
final request = Request.get(
  'https://postman-echo.com/get?a=b',
  headers: {'header-name':'header-value'}.asHeaders(),
  queries: {'query-name':'query-value'}.asQueries(),
);
```

You can use `HeadersBuilder` and `QueriesBuilder` too.

```dart
final builder = HeadersBuilder();
builder.add('header-name', 'header-value');
builder.set('header-name', 'header-value-2');
builder.removeAll('header-name');
final headers = builder.build();
```

### Performing a GET request

```dart
final client = Restio();
final request = get('https://postman-echo.com/get');
final call = client.newCall(request);
final response = await call.execute();
```

### Performing a POST request

```dart
final request = post(
  'https://postman-echo.com/post',
  body: 'This is expected to be sent back as part of response body.'.asBody(),
);
final call = client.newCall(request);
final response = await call.execute();
```

### Get response stream
```dart
final stream = response.body.data;
await response.close();
```

### Get raw response bytes

```dart
final bytes = await response.body.raw();
await response.close();
```

### Get decompressed response bytes (gzip, deflate or brotli)

```dart
final bytes = await response.body.decompressed();
await response.close();
```

### Get response string

```dart
final string = await response.body.string();
await response.close();
```

### Get response JSON

```dart
final json = await response.body.json();
await response.close();
```

### Sending form data
```dart
final request = post(
  'https://postman-echo.com/post',
  body: {
    'foo1': 'bar1',
    'foo2': 'bar2',
  }.asForm(),
);
final call = client.newCall(request);
final response = await call.execute();
```

### Sending multipart data

```dart
final request = post(
  'https://postman-echo.com/post',
  body: {'file1': File('./upload.txt')}.asMultipart(),
);
final call = client.newCall(request);
final response = await call.execute();
```

or

```dart
final request = post(
  'https://postman-echo.com/post',
  body: MultipartBody(
    parts: [
      // File.
      Part.file(
        // field name.
        'file1', 
        // file name.
        'upload.txt', 
        // file content.
        RequestBody.file(
          File('./upload.txt'),
          contentType: MediaType.text,
        ),
      ),
      // Text.
      Part.form('a', 'b'),
    ],
  ),
);
```

### Posting binary data

```dart
// Binary data.
final data = <int>[...];
final request = post(
  'https://postman-echo.com/post',
  body: data.asBody(),
);
final call = client.newCall(request);
final response = await call.execute();
```

### Listening for download progress

```dart
void onProgress(Response res, int length, int total, bool done) {
  print('length: $length, total: $total, done: $done');
};

final client = Restio(onDownloadProgress: onProgress);
final request = get('https://httpbin.org/stream-bytes/36001');
final call = client.newCall(request);
final response = await call.execute();
final data = await response.body.raw();
await response.close();
```

### Listening for upload progress

```dart
void onProgress(Request req, int length, int total, bool done) {
  print('length: $length, total: $total, done: $done');
};

final client = Restio(onUploadProgress: onProgress);
final request = post('https://postman-echo.com/post',
  body: File('./large_file.txt').asBody(),
);

final call = client.newCall(request);
final response = await call.execute();
```

### Pause & Resume retrieving response data

```dart
final response = await call.execute();
final body = response.body;
final data = await body.raw();
await response.close();

// Called from any callback.
body.pause();

body.resume();
```

### Interceptors

```dart
final client = Restio(
  interceptors: const [MyInterceptor()],
  networkInterceptors: const [MyInterceptor()],
);

class MyInterceptor implements Interceptor {
  const MyInterceptor();

  @override
  Future<Response> intercept(Chain chain) async {
    final request = chain.request;
    print('Sending request: $request');
    final response = await chain.proceed(chain.request);
    print('Received response: $response');
    return response;
  }
}
```

### Authentication

```dart
final client = Restio(
  options: const RequestOptions(
    authenticator: BasicAuthenticator(
      username: 'postman',
      password: 'password',
    ),
  ),
);

final request = get('https://postman-echo.com/basic-auth');

final call = client.newCall(request);
final response = await call.execute();
```

> Supports Bearer, Digest and Hawk Authorization Method too.

### Cookie Manager

```dart
final client = Restio(cookieJar: const MyCookieJar());

class MyCookieJar implements CookieJar {
  const MyCookieJar();

  @override
  Future<List<Cookie>> load(Request request) async {
    // TODO:
  }

  @override
  Future<void> save(Response response) async {
    final cookies = response.cookies;
    // TODO:
  }
}
```

### Custom Client Certificates

```dart
final client = Restio(
  certificates: [
    Certificate(
      host: 'client.badssl.com', // supports wildcard too!
      certificate: File('./test/assets/badssl.com-client.pem').readAsBytesSync(),
      privateKey: File('./test/assets/badssl.com-client.p12').readAsBytesSync(),
      port: 443, // Optional.
      password: 'badssl.com',
    ),
  ],
);
final request = get('https://client.badssl.com/');
final call = client.newCall(request);
final response = await call.execute();
await response.close();
```

You can pass in RequestOptions too. The `host` and `port` will be ignored.

### Handling Errors

```dart
try {
  final response = await call.execute();
} on CancelledException catch(e) {
  // TODO:
} on TooManyRedirectsException catch(e) {
  // TODO:
} on TimedOutException catch(e) {
  // TODO:
} on RestioException catch(e) {
  // TODO:
}
```

### Cancellation

```dart
final call = client.newCall(request);
final response = await call.execute();

// Cancel the request with 'cancelled' message.
call.cancel('cancelled');
```

### Proxy

```dart
final client = Restio(
  options: const RequestOptions(
    proxy: Proxy(
      host: 'localhost',
      port: 3001,
    ),
  ),
);

final request = get('http://localhost:3000');
final call = client.newCall(request);
final response = await call.execute();
```

### HTTP2

```dart
final client = Restio(options: const RequestOptions(http2: true));
final request = get('https://www.google.com/');
final call = client.newCall(request);
final response = await call.execute();
```

### WebSocket

```dart
final client = Restio();
final request = Request(uri: RequestUri.parse('wss://echo.websocket.org'));
final ws = client.newWebSocket(request);
final conn = await ws.open();

// Receive.
conn.stream.listen((dynamic data) {
  print(data);
});

// Send.
conn.addString('❤️ Larichan ❤️');

await conn.close();
```

### SSE

```dart
final client = Restio();
final request = Request(uri: RequestUri.parse('https://my.sse.com'));
final sse = client.newSse(
  request,
  lastEventId: '0', // Optional. Specifies the value of the event source’s last event ID
  retryInterval: const Duration(seconds: 1), // Optional. Enables auto reconnect and specifies the interval between retry attempts.
  maxRetries: 1, // Optional. The maximum amount of retries for auto reconnect. Use null or -1 for infinite.
);
final conn = await sse.open();

// Listen.
conn.stream.listen((SseEvent event) {
  print(event.id);
  print(event.event);
  print(event.data);
});

await conn.close();
```

### DNS

Thanks to [dart-protocol](https://github.com/dart-protocol) for this great [dns](https://github.com/dart-protocol/dns) library!

```dart
final dns = DnsOverUdp.google();
final client = Restio(options: RequestOptions(dns: dns));
final request = get('https://postman-echo.com/get');
final call = client.newCall(request);
final response = await call.execute();

print(response.address); // Prints the resolved IP address.
```

> Supports DnsOverHttps too.

### Caching (RFC 7234)

```dart
final store = await LruCacheStore.local('./cache');
final cache = Cache(store: store);
final client = Restio(cache: cache);

final request = get('https://postman-echo.com/get');
final call = client.newCall(request);
final response = await call.execute();

final networkResponse = response.networkResponse; // From network validation.
final cacheResponse = response.cacheResponse; // From cache.
```

> Supports LruCacheStore.memory() too.

with encryption:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

final key = Key.fromUtf8('TLjBdXJxDiqHAFWQAk68NyEtK9D8XYEG');
final encrypter = Encrypter(Fernet(Key.fromUtf8(base64.encode(key.bytes))));

Uint8List encrypt(List<int> data) {
  data = base64Encode(data).codeUnits;
  return encrypter.encryptBytes(data).bytes;
}

List<int> decrypt(Uint8List data) {
  return base64Decode(encrypter.decrypt(Encrypted(data)));
}

final store = await LruCacheStore.local('./cache', decrypt: decrypt, encrypt: encrypt);
```

### Mocking

```dart
final mockClient = Restio(
  networkInterceptors: [
    MockInterceptor(
      [
        Response(code: 200, body: ResponseBody.string('OK')),
      ],
    ),
  ],
);

final request = Request.get('http://mock.test.io');
final call = mockClient.newCall(request);
final response = await call.execute();

expect(response.code, 200);
expect(await response.body.string(), 'OK');
await response.close();
```

## Projects using this library

* [Restler](https://play.google.com/store/apps/details?id=br.tiagohm.restler): Restler is an Android app built with simplicity and ease of use in mind. It allows you send custom HTTP/HTTPS requests and test your REST API anywhere and anytime.
