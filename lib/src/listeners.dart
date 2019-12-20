import 'dart:io';

import 'package:restio/restio.dart';

typedef RequestProgressListener = void Function(
  Request request,
  int sent,
  int total,
  bool done,
);

typedef ResponseProgressListener = void Function(
  Response response,
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
