import 'dart:convert';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

final key = Key.fromUtf8('TLjBdXJxDiqHAFWQAk68NyEtK9D8XYEG');
final fernet = Fernet(key);
final encrypter = Encrypter(fernet);

Uint8List encrypt(List<int> data) {
  data = base64Encode(data).codeUnits;
  return encrypter.encryptBytes(data).bytes;
}

List<int> decrypt(Uint8List data) {
  return base64Decode(encrypter.decrypt(Encrypted(data)));
}
