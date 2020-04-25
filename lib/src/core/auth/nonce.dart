import 'dart:math';

import 'package:equatable/equatable.dart';

const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
final _random = Random();

class Nonce extends Equatable {
  final String value;

  // ignore: prefer_is_empty
  const Nonce(this.value) : assert(value != null && value.length > 0);

  factory Nonce.random(int length) {
    final nonce = StringBuffer('');

    for (var i = 0; i < length; i++) {
      nonce.write(_chars[(_random.nextInt(_chars.length))]);
    }

    return Nonce(nonce.toString());
  }

  @override
  String toString() => value;

  @override
  List<Object> get props => [value];
}
