import 'dart:convert';

import 'package:http_parser/http_parser.dart';
import 'package:restio/src/utils.dart';

class Challenge {
  final String scheme;
  final Map<String, String> parameters;

  const Challenge({
    this.scheme,
    this.parameters = const {},
  });

  static List<Challenge> parse(String text) {
    try {
      final challenges = AuthenticationChallenge.parseHeader(text);
      return [
        for (final challenge in challenges)
          Challenge(scheme: challenge.scheme, parameters: challenge.parameters)
      ];
    } catch (e) {
      // Falha em https://httpbin.org/bearer.
      return const [];
    }
  }

  Challenge.withRealmAndCharset(
    this.scheme,
    String realm, [
    String charset = 'utf-8',
  ]) : parameters = {'realm': realm, 'charset': charset};

  bool get isBasic => scheme?.toLowerCase() == 'basic';

  bool get isDigest => scheme?.toLowerCase() == 'digest';

  bool get isBearer => scheme?.toLowerCase() == 'bearer';

  bool get isOauth => scheme?.toLowerCase() == 'oauth';

  bool get isHawk => scheme?.toLowerCase() == 'hawk';

  String get realm => parameters['realm'];

  Encoding get encoding => obtainEncodingByName(parameters['charset'], latin1);

  Challenge copyWith({
    String scheme,
    Map<String, String> parameters,
  }) {
    return Challenge(
      scheme: scheme ?? this.scheme,
      parameters: parameters ?? this.parameters,
    );
  }
}
