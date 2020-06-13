import 'dart:io';

typedef ProgressCallback<T> = void Function(
  T entity,
  int length,
  int total,
  bool done,
);

typedef BadCertificateCallback = bool Function(
  X509Certificate cert,
  String host,
  int port,
);
