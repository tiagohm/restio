import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:http_parser/http_parser.dart';
import 'package:restio/src/utils.dart';

class Challenge extends Equatable {
  final String scheme;
  final Map<String, String> parameters;

  const Challenge({
    this.scheme,
    Map<String, String> parameters = const {},
  }) : parameters = parameters ?? const {};

  static List<Challenge> parse(String text) {
    try {
      final challenges = AuthenticationChallenge.parseHeader(text);
      return [
        for (final challenge in challenges)
          Challenge(
            scheme: challenge.scheme,
            parameters: challenge.parameters,
          ),
      ];
    } catch (e) {
      // Falha em https://httpbin.org/bearer.
      return const [];
    }
  }

  bool get isBasic => scheme?.toLowerCase() == 'basic';

  bool get isDigest => scheme?.toLowerCase() == 'digest';

  bool get isBearer => scheme?.toLowerCase() == 'bearer';

  bool get isOauth => scheme?.toLowerCase() == 'oauth';

  bool get isHawk => scheme?.toLowerCase() == 'hawk';

  String get realm => parameters['realm'];

  String get charset => parameters['charset'];

  Encoding get encoding => obtainEncodingByName(charset, latin1);

  Challenge copyWith({
    String scheme,
    Map<String, String> parameters,
    String charset,
  }) {
    return Challenge(
      scheme: scheme ?? this.scheme,
      parameters: {
        ...parameters ?? this.parameters,
        if (charset != null) 'charset': charset,
      },
    );
  }

  @override
  List<Object> get props => [scheme, parameters];
}
