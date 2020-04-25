import 'dart:io';

typedef ProgressCallback = void Function(
  int sent,
  int total,
  bool done,
);

typedef BadCertificateCallback = bool Function(
  X509Certificate cert,
  String host,
  int port,
);
