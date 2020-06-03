import 'dart:convert';
import 'dart:io';

import 'package:mime_type/mime_type.dart';
import 'package:path/path.dart';
import 'package:restio/src/common/encoding.dart';
import 'package:restio/src/common/item.dart';

class MediaType extends Item {
  final String type;
  final String subType;
  final Map<String, String> parameters;

  static const formUrlEncoded = MediaType(
    type: 'application',
    subType: 'x-www-form-urlencoded',
  );

  static const multipartMixed = MediaType(
    type: 'multipart',
    subType: 'mixed',
  );

  static const multipartAlternative = MediaType(
    type: 'multipart',
    subType: 'alternative',
  );

  static const multipartDigest = MediaType(
    type: 'multipart',
    subType: 'digest',
  );

  static const multipartParallel = MediaType(
    type: 'multipart',
    subType: 'parallel',
  );

  static const multipartFormData = MediaType(
    type: 'multipart',
    subType: 'form-data',
  );

  static const json = MediaType(
    type: 'application',
    subType: 'json',
    parameters: {'charset': 'utf-8'},
  );

  static const octetStream = MediaType(
    type: 'application',
    subType: 'octet-stream',
  );

  static const text = MediaType(
    type: 'text',
    subType: 'plain',
    parameters: {'charset': 'utf-8'},
  );

  const MediaType({
    this.type,
    this.subType,
    Map<String, String> parameters,
  }) : parameters = parameters ?? const {};

  factory MediaType.fromContentType(ContentType contentType) {
    return MediaType(
      type: contentType?.primaryType ?? 'application',
      subType: contentType?.subType ?? 'octet-stream',
      parameters: {
        if (contentType?.parameters != null) ...contentType.parameters,
      },
    );
  }

  factory MediaType.parse(String text) {
    return text == null
        ? null
        : MediaType.fromContentType(ContentType.parse(text));
  }

  factory MediaType.fromFile(
    String path, {
    String charset,
  }) {
    final ext = extension(path)?.replaceAll('.', '');
    final mimeType = mimeFromExtension(ext);
    final mediaType =
        mimeType != null ? MediaType.parse(mimeType) : MediaType.octetStream;
    return mediaType.copyWith(charset: charset);
  }

  @override
  String get name => 'Content-Type';

  @override
  String get value => toHeaderString();

  MediaType copyWith({
    String type,
    String subType,
    String charset,
    String boundary,
    Map<String, String> parameters,
  }) {
    Map<String, String> p;

    if (charset != null || boundary != null || parameters != null) {
      p = {
        if (parameters != null) ...parameters,
        if (charset != null) 'charset': charset,
        if (boundary != null) 'boundary': boundary,
      };
    }

    return MediaType(
      type: type ?? this.type,
      subType: subType ?? this.subType,
      parameters: p ?? this.parameters,
    );
  }

  ContentType toContentType() {
    return ContentType(
      type,
      subType,
      parameters: parameters,
    );
  }

  String get mimeType => '$type/$subType';

  String get charset => parameters['charset'];

  String get boundary => parameters['boundary'];

  Encoding get encoding => encodingByName(
        parameters['charset'],
        type == 'multipart' ? utf8 : _defaultEncoding(mimeType),
      );

  static Encoding _defaultEncoding(String mimeType) {
    return mimeType == 'application/json' || mimeType == 'text/plain'
        ? utf8
        : latin1;
  }

  String toHeaderString() {
    final text = StringBuffer()..write('$mimeType');

    if (parameters != null) {
      for (final name in parameters.keys) {
        final value = parameters[name];

        if (value != null) {
          text.write('; $name=$value');
        }
      }
    }

    return text.toString();
  }

  @override
  String toString() {
    return 'MediaType { type: $type, subType: $subType,'
        ' parameters: $parameters }';
  }

  @override
  List<Object> get props => [type, subType, parameters];
}
