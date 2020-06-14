import 'dart:convert';
import 'dart:typed_data';

import 'package:file/file.dart';

typedef Encrypt = Uint8List Function(List<int> data);

typedef Decrypt = List<int> Function(Uint8List data);

class EncryptedFile implements File {
  final File file;
  final Encrypt encrypt;
  final Decrypt decrypt;

  EncryptedFile(
    this.file, {
    this.encrypt,
    this.decrypt,
  });

  Uint8List _encryptData(List<int> data) {
    return data != null && data.isNotEmpty && encrypt != null
        ? encrypt(data)
        : data is Uint8List ? data : Uint8List.fromList(data);
  }

  List<int> _decryptData(Uint8List data) {
    return data != null && data.isNotEmpty && decrypt != null
        ? decrypt(data)
        : data;
  }

  @override
  File get absolute => file.absolute;

  @override
  String get basename => file.basename;

  @override
  Future<File> copy(String newPath) {
    return file.copy(newPath);
  }

  @override
  File copySync(String newPath) {
    return file.copySync(newPath);
  }

  @override
  Future<File> create({
    bool recursive = false,
  }) {
    return file.create(recursive: recursive);
  }

  @override
  void createSync({bool recursive = false}) {
    file.createSync(recursive: recursive);
  }

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) {
    return file.delete(recursive: recursive);
  }

  @override
  void deleteSync({bool recursive = false}) {
    file.deleteSync(recursive: recursive);
  }

  @override
  String get dirname => file.dirname;

  @override
  Future<bool> exists() {
    return file.exists();
  }

  @override
  bool existsSync() {
    return file.existsSync();
  }

  @override
  FileSystem get fileSystem => file.fileSystem;

  @override
  bool get isAbsolute => file.isAbsolute;

  @override
  Future<DateTime> lastAccessed() {
    return file.lastAccessed();
  }

  @override
  DateTime lastAccessedSync() {
    return file.lastAccessedSync();
  }

  @override
  Future<DateTime> lastModified() {
    return file.lastModified();
  }

  @override
  DateTime lastModifiedSync() {
    return file.lastModifiedSync();
  }

  @override
  Future<int> length() {
    return file.length();
  }

  @override
  int lengthSync() {
    return file.lengthSync();
  }

  @override
  Future<RandomAccessFile> open({
    FileMode mode = FileMode.read,
  }) {
    throw UnimplementedError();
  }

  @override
  Stream<List<int>> openRead([int start, int end]) {
    return file.openRead(start, end).transform(_DecryptConverter(decrypt));
  }

  @override
  RandomAccessFile openSync({
    FileMode mode = FileMode.read,
  }) {
    throw UnimplementedError();
  }

  @override
  IOSink openWrite({
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
  }) {
    final sink = file.openWrite(mode: mode, encoding: encoding);
    return _EncryptIOSink(sink, encrypt);
  }

  @override
  Directory get parent => file.parent;

  @override
  String get path => file.path;

  @override
  Future<Uint8List> readAsBytes() async {
    final data = _decryptData(await file.readAsBytes());
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  @override
  Uint8List readAsBytesSync() {
    final data = _decryptData(file.readAsBytesSync());
    return data is Uint8List ? data : Uint8List.fromList(data);
  }

  @override
  Future<List<String>> readAsLines({
    Encoding encoding = utf8,
  }) {
    throw UnimplementedError();
  }

  @override
  List<String> readAsLinesSync({
    Encoding encoding = utf8,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<String> readAsString({
    Encoding encoding = utf8,
  }) async {
    final data = await readAsBytes();
    return encoding.decode(data);
  }

  @override
  String readAsStringSync({
    Encoding encoding = utf8,
  }) {
    final data = readAsBytesSync();
    return encoding.decode(data);
  }

  @override
  Future<File> rename(String newPath) {
    return file.rename(newPath);
  }

  @override
  File renameSync(String newPath) {
    return file.renameSync(newPath);
  }

  @override
  Future<String> resolveSymbolicLinks() {
    return file.resolveSymbolicLinks();
  }

  @override
  String resolveSymbolicLinksSync() {
    return file.resolveSymbolicLinksSync();
  }

  @override
  Future setLastAccessed(DateTime time) {
    return file.setLastAccessed(time);
  }

  @override
  void setLastAccessedSync(DateTime time) {
    file.setLastAccessedSync(time);
  }

  @override
  Future setLastModified(DateTime time) {
    return file.setLastModified(time);
  }

  @override
  void setLastModifiedSync(DateTime time) {
    file.setLastModifiedSync(time);
  }

  @override
  Future<FileStat> stat() {
    return file.stat();
  }

  @override
  FileStat statSync() {
    return file.statSync();
  }

  @override
  Uri get uri => file.uri;

  @override
  Stream<FileSystemEvent> watch({
    int events = FileSystemEvent.all,
    bool recursive = false,
  }) {
    return file.watch(events: events, recursive: recursive);
  }

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    final data = _encryptData(bytes);
    return file.writeAsBytes(data, mode: mode, flush: flush);
  }

  @override
  void writeAsBytesSync(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    final data = _encryptData(bytes);
    file.writeAsBytesSync(data, mode: mode, flush: flush);
  }

  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    final data = encoding.encode(contents);
    return writeAsBytes(data, mode: mode, flush: flush);
  }

  @override
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) {
    final data = encoding.encode(contents);
    writeAsBytesSync(data, mode: mode, flush: flush);
  }
}

class _DecryptConverter extends Converter<Uint8List, List<int>> {
  final Decrypt decrypt;

  const _DecryptConverter(this.decrypt);

  @override
  List<int> convert(List<int> input) {
    return decrypt?.call(input) ?? input;
  }

  @override
  Sink<Uint8List> startChunkedConversion(Sink<List<int>> sink) {
    return ChunkedConversionSink.withCallback((data) {
      if (data.isNotEmpty) {
        if (data[0].isNotEmpty && decrypt != null) {
          sink.add(decrypt(data[0]));
        } else {
          sink.add(data[0]);
        }
      }

      sink.close();
    });
  }
}

class _EncryptIOSink implements IOSink {
  final IOSink sink;
  final Encrypt encrypt;
  final _data = <int>[];

  _EncryptIOSink(this.sink, this.encrypt);

  @override
  Encoding get encoding => sink.encoding;

  @override
  set encoding(Encoding value) => sink.encoding = value;

  @override
  void add(List<int> data) {
    _data.addAll(data);
  }

  @override
  void addError(
    Object error, [
    StackTrace stackTrace,
  ]) {
    sink.addError(error, stackTrace);
  }

  @override
  Future addStream(Stream<List<int>> stream) {
    return stream.listen(add).asFuture();
  }

  @override
  Future close() {
    if (_data.isNotEmpty && encrypt != null) {
      sink.add(encrypt(_data));
    } else {
      sink.add(_data);
    }

    return sink.close();
  }

  @override
  Future get done => sink.done;

  @override
  Future flush() {
    return sink.flush();
  }

  @override
  void write(Object obj) {
    add(encoding.encode(obj.toString()));
  }

  @override
  void writeAll(
    Iterable objects, [
    String separator = "",
  ]) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) {
    _data.add(charCode);
  }

  @override
  void writeln([Object obj = ""]) {
    write(obj);
    write('\n');
  }
}
