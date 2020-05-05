import 'dart:io';
import 'dart:math';

import 'package:file/memory.dart';
import 'package:restio/src/common/encrypted_file_system.dart';
import 'package:test/test.dart';

import 'fernet.dart';

const stringData = '012345';
const bytesData = [48, 49, 50, 51, 52, 53];

void main() {
  test('Encrypt & Decrypt As String', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    await file.writeAsString(stringData);
    expect(await file.readAsString(), stringData);
  });

  test('Encrypt & Decrypt As String', () {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    file.writeAsStringSync(stringData);
    expect(file.readAsStringSync(), stringData);
  });

  test('Encrypt & Decrypt As Bytes', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    await file.writeAsBytes(bytesData);
    expect(await file.readAsBytes(), bytesData);
  });

  test('Encrypt & Decrypt As Bytes Sync', () {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    file.writeAsBytesSync(bytesData);
    expect(file.readAsBytesSync(), bytesData);
  });

  test('Encrypt As Bytes & Decrypt As String', () {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    file.writeAsBytesSync(bytesData);
    expect(file.readAsStringSync(), stringData);
  });

  test('Encrypt As String & Decrypt As Bytes', () {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    file.writeAsStringSync(stringData);
    expect(file.readAsBytesSync(), bytesData);
  });

  test('Encrypt As Bytes & Decrypt As Stream', () {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    file.writeAsBytesSync(bytesData);
    expect(file.openRead(), emitsInOrder([bytesData]));
  });

  test('Encrypt As Stream & Decrypt As Bytes', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    final sink = file.openWrite();
    await sink.addStream(Stream.value(bytesData));
    await sink.close();

    expect(file.readAsBytesSync(), bytesData);
  });

  test('Encrypt & Decrypt Empty Data', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    file.writeAsBytesSync(const []);
    expect(file.readAsBytesSync(), const []);
  });

  test('Encrypt & Decrypt Random Data', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    final random = Random();
    final data = List.generate(26, (i) => random.nextInt(8));
    file.writeAsBytesSync(data);
    expect(file.readAsBytesSync(), data);
  });

  test('Encrypt & Decrypt Data Filled With Zeroes', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    final data = List.filled(26, 0);
    file.writeAsBytesSync(data);
    expect(file.readAsBytesSync(), data);
  });

  test('Encrypt & Decrypt Value Greater Than 127', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    final data = [128];
    file.writeAsBytesSync(data);
    expect(file.readAsBytesSync(), data);
  });

  test('Encrypt & Decrypt Gzip Data', () async {
    final mfs = MemoryFileSystem();
    final efs = EncryptedFileSystem(mfs, encrypt: encrypt, decrypt: decrypt);
    final file = efs.file('/test.aes');

    final data = gzip.encode(bytesData);
    file.writeAsBytesSync(data);
    expect(file.readAsBytesSync(), data);
  });
}
