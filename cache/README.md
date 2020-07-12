# Cache

HTTP Cache ([RFC 7234](https://tools.ietf.org/html/rfc7234)) support for Restio using LRU replacement strategy.

## Installation

In `pubspec.yaml` add the following dependencies:

```yaml
dependencies:
  restio_cache: ^0.1.2
```

## Usage

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

> Supports `LruCacheStore.memory()` too.

With encryption using [encrypt](https://pub.dev/packages/encrypt) package:

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
