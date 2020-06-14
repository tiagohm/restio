import 'package:file/file.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:restio_cache/src/encrypted_file.dart';

class EncryptedFileSystem implements FileSystem {
  final FileSystem fileSystem;
  final Encrypt encrypt;
  final Decrypt decrypt;

  const EncryptedFileSystem(
    this.fileSystem, {
    @required this.encrypt,
    @required this.decrypt,
  });

  @override
  Directory get currentDirectory => fileSystem.currentDirectory;

  @override
  set currentDirectory(value) {
    fileSystem.currentDirectory = value;
  }

  @override
  Directory directory(path) {
    return fileSystem.directory(path);
  }

  @override
  File file(path) {
    return EncryptedFile(
      fileSystem.file(path),
      encrypt: encrypt,
      decrypt: decrypt,
    );
  }

  @override
  String getPath(path) {
    return fileSystem.getPath(path);
  }

  @override
  Future<bool> identical(String path1, String path2) {
    return fileSystem.identical(path1, path2);
  }

  @override
  bool identicalSync(String path1, String path2) {
    return fileSystem.identicalSync(path1, path2);
  }

  @override
  Future<bool> isDirectory(String path) {
    return fileSystem.isDirectory(path);
  }

  @override
  bool isDirectorySync(String path) {
    return fileSystem.isDirectorySync(path);
  }

  @override
  Future<bool> isFile(String path) {
    return fileSystem.isFile(path);
  }

  @override
  bool isFileSync(String path) {
    return fileSystem.isFileSync(path);
  }

  @override
  Future<bool> isLink(String path) {
    return fileSystem.isLink(path);
  }

  @override
  bool isLinkSync(String path) {
    return fileSystem.isLinkSync(path);
  }

  @override
  bool get isWatchSupported => fileSystem.isWatchSupported;

  @override
  Link link(path) {
    return fileSystem.link(path);
  }

  @override
  Context get path => fileSystem.path;

  @override
  Future<FileStat> stat(String path) {
    return fileSystem.stat(path);
  }

  @override
  FileStat statSync(String path) {
    return fileSystem.statSync(path);
  }

  @override
  Directory get systemTempDirectory => fileSystem.systemTempDirectory;

  @override
  Future<FileSystemEntityType> type(
    String path, {
    bool followLinks = true,
  }) {
    return fileSystem.type(path, followLinks: followLinks);
  }

  @override
  FileSystemEntityType typeSync(
    String path, {
    bool followLinks = true,
  }) {
    return fileSystem.typeSync(path, followLinks: followLinks);
  }
}
