import 'package:meta/meta.dart';

/// Define an API.
@immutable
class Api {
  final String baseUri;

  const Api([this.baseUri]);
}

/// Use a custom HTTP verb for a request.
@immutable
class Method {
  /// The HTTP verb.
  final String name;

  /// A relative or absolute path, or full URL of the endpoint.
  final String path;

  const Method(this.name, this.path)
      : assert(name != null),
        assert(path != null);
}

/// Make a `GET` request.
@immutable
class Get extends Method {
  const Get(String path) : super('GET', path);
}

/// Make a `POST` request.
@immutable
class Post extends Method {
  const Post(String path) : super('POST', path);
}

/// Make a `DELETE` request.
@immutable
class Delete extends Method {
  const Delete(String path) : super('DELETE', path);
}

/// Make a `PUT` request.
@immutable
class Put extends Method {
  const Put(String path) : super('PUT', path);
}

/// Make a `PATCH` request.
@immutable
class Patch extends Method {
  const Patch(String path) : super('PATCH', path);
}

/// Make a `HEAD` request.
@immutable
class Head extends Method {
  const Head(String path) : super('HEAD', path);
}

/// Make an `OPTIONS` request.
@immutable
class Options extends Method {
  const Options(String path) : super('OPTIONS', path);
}

/// Named replacement in a URL path segment.
@immutable
class Path {
  final String name;

  const Path([this.name]);
}

@immutable
abstract class Param {
  const Param();

  String get name;

  String get value;
}

/// Query parameter appended to the URL.
/// Annotate a parameter to replace the query [name] with the value
/// of its target. If [name] is null, the parameter name will be used.
///
/// Annotate a method to add header literally with [name] and [value].
@immutable
class Query extends Param {
  @override
  final String name;
  @override
  final String value;

  const Query([this.name, this.value]);
}

/// Annotate a parameter to append to the URL the queries specified.
@immutable
class Queries {
  const Queries();
}

/// Annotate a parameter to replace the header [name] with the value
/// of its target. If [name] is null, the parameter name will be used.
///
/// Annotate a method to add header literally with [name] and [value].
/// If [value] is null, the header will not be used.
@immutable
class Header extends Param {
  @override
  final String name;
  @override
  final String value;

  const Header([this.name, this.value]);
}

/// Annotate a parameter to add headers specified.
@immutable
class Headers {
  const Headers();
}

/// Denotes that the parameter is a request body.
@immutable
class Body {
  final String contentType;
  final String charset;

  const Body({
    this.contentType,
    this.charset,
  });
}

/// Annotate a method to indicate that the request body will use form URL
/// encoding. Fields could be declared as parameters and annotated with [Field].
///
/// Annotate a parameter to add named key/value pairs for a form-encoded request.
///
/// Requests made with this annotation will have
/// application/x-www-form-urlencoded MIME type.
/// Field names and values will be UTF-8 encoded before being URI-encoded
/// in accordance to RFC-3986.
@immutable
class Form extends Body {
  const Form() : super(contentType: 'application/x-www-form-urlencoded');
}

/// Annotate a parameter to add named pair for a form-encoded request.
/// If [name] is null, the parameter name will be used.
///
/// Annotate a method to add form field literally with [name] and [value].
/// If [value] is null, the field will not be used.
@immutable
class Field extends Param {
  @override
  final String name;
  @override
  final String value;

  const Field([this.name, this.value]);
}

/// Annotate a method to indicate that the request body is multi-part.
/// Parts could be declared as parameters and annotated with [Part].
///
/// Annotate a parameter to add named key/value pairs for a form-encoded request.
@immutable
class Multipart extends Body {
  final String boundary;

  const Multipart({
    String contentType,
    this.boundary,
    String charset,
  }) : super(contentType: contentType, charset: charset);
}

/// Annotate a parameter to denote a single part of a multi-part request.
/// The [filename], [contentType] and [charset] properties is used only
/// for [File].
@immutable
class Part {
  final String name;
  final String filename;
  final String contentType;
  final String charset;

  const Part({
    this.name,
    this.filename,
    this.contentType,
    this.charset,
  });
}

/// Annotate a parameter to pass the parameter value
/// to [Request]'s extra property.
@immutable
class Extra {
  const Extra();
}

/// Annotate a method to indicate that the response should not be decompressed.
@immutable
class Raw {
  const Raw();
}

/// Annotate a method to indicate that one may throws an [HttpStatusException]
/// if response code between [min] and [max].
@immutable
class Throws {
  /// Minimum response code (inclusive).
  final int min;

  /// Maximum response code (exclusive).
  final int max;

  /// Negate the comparison.
  final bool negate;

  const Throws(
    this.min,
    this.max, {
    this.negate = false,
  })  : assert(min != null && min >= 0),
        assert(max != null && max >= 0),
        assert(max >= min),
        assert(negate != null);

  const Throws.only(this.min)
      : max = min + 1,
        negate = false;

  const Throws.not(this.min)
      : max = min + 1,
        negate = true;

  const Throws.redirect()
      : min = 300,
        max = 400,
        negate = false;

  const Throws.notRedirect()
      : min = 300,
        max = 400,
        negate = true;

  const Throws.error()
      : min = 400,
        max = 600,
        negate = false;

  const Throws.clientError()
      : min = 400,
        max = 500,
        negate = false;

  const Throws.serverError()
      : min = 500,
        max = 600,
        negate = false;
}

/// Annotate a method to indicate that one will not throws an
///  [HttpStatusException].
@immutable
class NotThrows extends Throws {
  const NotThrows() : super(0, 0);
}

/// Annotate a class to register a complex class converter.
@immutable
class Converter {
  final Type type;
  final Type converter;

  const Converter(this.type, this.converter);
}

/// Annotate a method to add Basic Authentication literally
/// with [user] and [pass].
///
/// Annotate a parameter to replace the [user] or [pass] parameter
/// with the value of its target.
@immutable
class BasicAuth {
  final String type;
  final String user;
  final String pass;

  const BasicAuth(this.user, this.pass) : type = null;

  const BasicAuth.username()
      : user = null,
        pass = null,
        type = 'user';

  const BasicAuth.password()
      : user = null,
        pass = null,
        type = 'pass';
}


/// Annotate a method to add Basic Authentication literally
/// with [user] and [pass].
///
/// Annotate a parameter to replace the [user] or [pass] parameter
/// with the value of its target.
@immutable
class DigestAuth {
  final String type;
  final String user;
  final String pass;

  const DigestAuth(this.user, this.pass) : type = null;

  const DigestAuth.username()
      : user = null,
        pass = null,
        type = 'user';

  const DigestAuth.password()
      : user = null,
        pass = null,
        type = 'pass';
}
