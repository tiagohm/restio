import 'package:equatable/equatable.dart';

abstract class Item extends Equatable {
  String get name;
  String get value;

  const Item();

  bool get isEmpty => value == null || value.isEmpty;

  bool get isNotEmpty => !isEmpty;

  bool get asBool {
    return value == '1' || value == 'true';
  }

  int get asInt {
    return value == null ? null : int.tryParse(value);
  }

  double get asDouble {
    return value == null ? null : double.tryParse(value);
  }

  num get asNum {
    return value == null ? null : num.tryParse(value);
  }

  @override
  List<Object> get props => [name, value];
}
