import 'dart:async';

import 'package:meta/meta.dart';
import 'package:restio/src/core/call.dart';
import 'package:restio/src/core/cancellable.dart';
import 'package:restio/src/core/client.dart';
import 'package:restio/src/core/response/response.dart';

abstract class ClientAdapter {
  @mustCallSuper
  Future<Response> execute(
    Restio client,
    Call call, [
    Cancellable cancellable,
  ]);
}
