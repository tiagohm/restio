# Restio

An HTTP Client for Dart inpired by [OkHttp](http://square.github.io/okhttp/).

### Installation

In `pubspec.yaml` add the following dependency:

```yaml
dependencies:
  restio: ^0.6.0
```

### How to use

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

### Recipes

#### Adding Headers and Queries:
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

#### Performing a GET request:

```dart
final client = Restio();
final request = get('https://postman-echo.com/get');
final call = client.newCall(request);
final response = await call.execute();
```

#### Performing a POST request:
```dart
final request = post(
  'https://postman-echo.com/post',
  body: 'This is expected to be sent back as part of response body.'.asBody(),
);
final call = client.newCall(request);
final response = await call.execute();
```

#### Get response stream:
```dart
final stream = response.body.data;
await response.close();
```

#### Get raw response bytes:
```dart
final bytes = await response.body.raw();
await response.close();
```

#### Get decompressed response bytes (gzip, deflate or brotli):
```dart
final bytes = await response.body.decompressed();
await response.close();
```

#### Get response string:
```dart
final string = await response.body.string();
await response.close();
```

#### Get response JSON:
```dart
final json = await response.body.json();
await response.close();
```

#### Sending form data:
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

#### Sending multipart data:
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
final request = Request.post(
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

#### Posting binary data:
```dart
// Binary data.
final postData = <int>[...];
final request = post(
  'https://postman-echo.com/post',
  body: postData.asBody(),
);
final call = client.newCall(request);
final response = await call.execute();
```

#### Listening for download progress:
```dart
final ProgressCallback onProgress = (Response res, int length, int total, bool done) {
  print('length: $length, total: $total, done: $done');
};

final progressClient = client.copyWith(
  onDownloadProgress: onProgress,
);

final request = get('https://httpbin.org/stream-bytes/36001');

final call = client.newCall(request);
final response = await call.execute();
final data = await response.body.raw();
await response.close();
```

#### Listening for upload progress:
```dart
final ProgressCallback onProgress = (Request req, int length, int total, bool done) {
  print('length: $length, total: $total, done: $done');
};

final progressClient = client.copyWith(
  onUploadProgress: onProgress,
);

final request = post('https://postman-echo.com/post',
  body: File('./large_file.txt').asBody(),
);

final call = client.newCall(request);
final response = await call.execute();
```

#### Pause & Resume retrieving response data
```dart
final response = await call.execute();
final responseBody = response.body;
final data = await responseBody.raw();
await response.close();

// Called from any callback.
responseBody.pause();

responseBody.resume();
```

#### Interceptors
```dart
final client = Restio(
  interceptors: [MyInterceptor()],
);

class MyInterceptor implements Interceptor {
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

#### Authentication
```dart
final client = Restio(
  authenticator: BasicAuthenticator(
    username: 'postman',
    password: 'password',
  ),
);

final request = get('https://postman-echo.com/basic-auth');

final call = client.newCall(request);
final response = await call.execute();
```

> Supports Bearer, Digest and Hawk Authorization Method too.

#### Cookie Manager
```dart
final client = Restio(
  cookieJar: MyCookieJar(),
);

class MyCookieJar extends CookieJar {

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

#### Handling Errors
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

#### Cancellation
```dart
final call = client.newCall(request);
final response = await call.execute();

// Cancel the request with 'cancelled' message.
call.cancel('cancelled');
```

#### Proxy
```dart
final client = Restio(
  proxy: Proxy(
    host: 'localhost',
    port: 3001,
  ),
);

final request = get('http://localhost:3000');
final call = client.newCall(request);
final response = await call.execute();
```

#### HTTP2

```dart
final client = Restio(http2: true);
final request = get('https://www.google.com/');
final call = client.newCall(request);
final response = await call.execute();
```

#### WebSocket
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

#### SSE
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

#### DNS

Thanks to [dart-protocol](https://github.com/dart-protocol) for this great [dns](https://github.com/dart-protocol/dns) library!

```dart
final dns = DnsOverUdp.google();
final client = Restio(
  dns: dns,
);

final request = get('https://postman-echo.com/get');
final call = client.newCall(request);
final response = await call.execute();

print(response.dnsIp); // Prints the resolved IP.
```

> Supports DnsOverHttps too.

#### Caching

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

### Projects using this library

* [Restler](https://play.google.com/store/apps/details?id=br.tiagohm.restler): Restler is an Android app built with simplicity and ease of use in mind. It allows you send custom HTTP/HTTPS requests and test your REST API anywhere and anytime.
