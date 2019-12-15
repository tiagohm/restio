import 'dart:async';

import 'package:restio/src/exceptions.dart';

class Cancellable {
  final _completer = Completer<dynamic>();
  Exception _exception;

  void cancel([String message]) {
    _exception = CancelledException(message);
    _completer.completeError(_exception);
  }

  Future get whenCancel => _completer.future;

  bool get isCancelled => _completer.isCompleted && _exception != null;

  Exception get exception => _exception;
}
