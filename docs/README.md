<span style="font-size: 53px;font-weight: bold;">Restio</span><small>0.6.0</small>

[![Star on GitHub](https://img.shields.io/github/stars/tiagohm/restio.svg?style=flat&logo=github&colorB=deeppink&label=stars)](https://github.com/tiagohm/restio)
[![style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://github.com/tenhobi/effective_dart)
[![Flutter Website](https://img.shields.io/badge/flutter-website-deepskyblue.svg)](https://flutter.dev)
[![Pub.dev](https://img.shields.io/pub/v/restio)](https://pub.dev/packages/restio)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)

> Simple HTTP and REST client for Dart.

## Features

* GET, POST, PUT, DELETE, HEAD, PATCH, OPTIONS, etc.
* Request Body can be List&lt;int&gt;, String, Stream, File and JSON Object too.
  * Auto detects Content-Type.
  * Buffer less processing for List&lt;int&gt;, String and File.
* Response Body gives you access as raw or decompressed data (List&lt;int&gt;), String and JSON Object too.
  * Decompress Gzip, Deflate or Brotli data.
* Easy to upload one or more file(s) via multipart/form-data.
  * Auto detects file content type.
* Interceptors using [Chain of responsibility](https://en.wikipedia.org/wiki/Chain-of-responsibility_pattern).
* Basic, Digest, Bearer and Hawk authorization methods.
* Send and save cookies for your request via CookieJar.
* Allows GET request with payload.
* Works fine with `HTTP/2` and `HTTP/1.1`.
* Response Caching applying [RFC 7234](https://tools.ietf.org/html/rfc7234) and Lru Cache.
* Custom Client Certificates.
* Proxy settings.
* DNS-over-UDP and DNS-over-HTTPS.
* WebSocket and SSE.

## Documentation

* [Official Documentation](https://restio.tiagohm.dev)
* [Restio package](https://github.com/tiagohm/restio/blob/master/README.md)

## Maintainers

* [Tiago Melo](https://github.com/tiagohm)