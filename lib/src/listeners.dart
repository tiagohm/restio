import 'dart:io';

import 'package:restio/restio.dart';

typedef ProgressListener<T> = void Function(
  T o,
  int sent,
  int total,
  bool done,
);

typedef BadCertificateListener = bool Function(
  Restio client,
  X509Certificate cert,
  String host,
  int port,
);
