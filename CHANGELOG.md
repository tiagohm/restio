## 0.7.0
 - SSE Automatic Reconnect supported.
 - Add RedirectPolicy support.
 - Added some extension methods to help you.
 - Minor bug fixes and performance improvements.
 - [Breaking]: Removed `MemoryCacheStore`, `DiskCacheStore` and `DiskLruCacheStore`. Use `LruCacheStore.memory()` or `LruCacheStore.local()`.
 - [Breaking]: Renamed `Event` to `SseEvent`.
 - [Breaking]: Removed `ClientAdapter` class.

## 0.6.0
 - Code refactoring.
 - Added DiskLruCacheStore class.
 - Fixed Hawk Auth bug.
 - Fixed DNS bug.
 - [Breaking]: `Restio(isHttp2: true)` -> `Restio(http2: true)`.
 - [Breaking]: `await response.body.close();` -> `await response.close();`.
 - [Breaking]: Dropped `cookies` parameter from `save` method in `CookieJar`. Use `response.cookies` instead.
 - [Breaking]: Dropped `data` attribute from `response.body`.
 - [Breaking]: Added (Request/Response) parameter to `ProgressCallback`.
 - [Breaking]: Use `response.body.data` to get data stream.

## 0.5.2
 - Fixed Request Query duplication bug.

## 0.5.1
 - Fixed Request Query bug.

## 0.5.0

- Fixed various bugs.
- Added RequestUri class.
- Renamed various methods.

## 0.4.3

- Fixed various bugs.

## 0.4.2

- Fixed SSE connection bug.

## 0.4.1

- Improvements.

## 0.4.0

- Added support to Cache (RFC 7234).
- Added support to SSE (Server-Sent Event).

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

- Added 'dnsIp' property.

## 0.3.0

- Added support to Brotli decode.

## 0.2.0+1

- Lint fixes.

## 0.2.0

- DNS;
- Bug fixes.

## 0.1.0

- Initial version.
