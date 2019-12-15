import 'dart:async';

import 'package:restio/src/call.dart';
import 'package:restio/src/cancellable.dart';
import 'package:restio/src/client.dart';
import 'package:restio/src/response.dart';
import 'package:meta/meta.dart';

abstract class ClientAdapter {
  @mustCallSuper
  Future<Response> execute(
    Restio client,
    Call call, [
    Cancellable cancellable,
  ]);
}
