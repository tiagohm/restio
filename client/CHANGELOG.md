## 0.10.0
 - Create `BodyConverter` class to allow add additional converters for request/response body formats.
 - Add `Restio.bodyConverter` static property.
 - Add `RequestBody.encode` static method.
 - Add `encode` method to `ResponseBody` class.

## 0.9.0
 - Move Cache implementation to another package [restio_cache](https://pub.dev/packages/restio_cache).

## 0.8.1
 - Fix Accept-Encoding bug.

## 0.8.0
 - Add Cache Encryption support.
 - Add Persistent Connection support.
 - Add HTTP2 Server Push support.
 - Allow send headers without to force to lowercase.
 - Add option to keep equal sign if query is empty.
 - Add `MultiAuthenticator` class.
 - Allow `Call` be executed multiple times.
 - [Breaking]: Move the most `Restio` parameters to `RequestOptions` class.
 - [Breaking]: Remove `ClientCertificateJar` and `ClientCertificate` classes. Use `Certificate` class at `Restio(certificates: [])` instead.
 - [Breaking]: Rename `increaseMaxSize()` to `setMaxSize()`.
 - [Breaking]: Rename `dnsIp` to `address`.
 - [Breaking]: Replace `connectionInfo` with `localPort`.
 - [Breaking]: Rename `FormItem` to `Field`.
 - Require min Dart SDK version 2.8.
 - Bug fixes.

## 0.7.1
 - Fix parse uri bug.

## 0.7.0
 - SSE Automatic Reconnect supported.
 - Add RedirectPolicy support.
 - Add some extension methods to help you.
 - Minor bug fixes and performance improvements.
 - [Breaking]: Remove `MemoryCacheStore`, `DiskCacheStore` and `DiskLruCacheStore`. Use `LruCacheStore.memory()` or `LruCacheStore.local()`.
 - [Breaking]: Rename `Event` to `SseEvent`.
 - [Breaking]: Remove `ClientAdapter` class.

## 0.6.0
 - Code refactoring.
 - Add DiskLruCacheStore class.
 - Fix Hawk Auth bug.
 - Fix DNS bug.
 - [Breaking]: `Restio(isHttp2: true)` -> `Restio(http2: true)`.
 - [Breaking]: `await response.body.close();` -> `await response.close();`.
 - [Breaking]: Drop `cookies` parameter from `save` method in `CookieJar`. Use `response.cookies` instead.
 - [Breaking]: Drop `data` attribute from `response.body`.
 - [Breaking]: Add (Request/Response) parameter to `ProgressCallback`.
 - [Breaking]: Use `response.body.data` to get data stream.

## 0.5.2
 - Fix Request Query duplication bug.

## 0.5.1
 - Fix Request Query bug.

## 0.5.0

- Fix various bugs.
- Add RequestUri class.
- Rename various methods.

## 0.4.3

- Fix various bugs.

## 0.4.2

- Fix SSE connection bug.

## 0.4.1

- Improvements.

## 0.4.0

- Add support to Cache (RFC 7234).
- Add support to SSE (Server-Sent Event).

## 0.3.5

- Fix DNS bug.
- Fix Brotli decompression bug.

## 0.3.4

- Fix DNS-over-HTTPS issue.

## 0.3.3

- Fix DNS bugs.

## 0.3.2

- Fix DNS timeout bug.

## 0.3.1

- Add 'dnsIp' property.

## 0.3.0

- Add support to Brotli decode.

## 0.2.0+1

- Lint fixes.

## 0.2.0

- DNS;
- Bug fixes.

## 0.1.0

- Initial version.
