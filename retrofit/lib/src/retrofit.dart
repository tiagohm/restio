import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:restio/restio.dart' as restio;
import 'package:restio_retrofit/src/annotations.dart' as annotations;
import 'package:restio_retrofit/src/const_expression.dart';
import 'package:source_gen/source_gen.dart';

class RetrofitGenerator extends GeneratorForAnnotation<annotations.Api> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Must be a class.
    if (element is! ClassElement) {
      final name = element.name;
      throw RetrofitError('Generator can not target `$name`.', element);
    }
    // Returns the generated API class.
    return _generate(element, annotation);
  }

  /// Returns the generated API class as [String].
  static String _generate(
    ClassElement element,
    ConstantReader annotation,
  ) {
    final classBuilder = _generateApi(element, annotation);
    final emitter = DartEmitter();
    final text = classBuilder.accept(emitter).toString();
    return DartFormatter().format(text);
  }

  /// Returns the generated API class.
  static Class _generateApi(
    ClassElement element,
    ConstantReader annotation,
  ) {
    // Name.
    final className = element.name;
    final name = '_$className';
    // Base URI.
    final baseUri = annotation.peek('baseUri')?.stringValue;

    final converters = _converters(element);

    return Class((c) {
      // Name.
      c.name = name;
      // Fields.
      c.fields.addAll([
        _generateField(
          name: 'client',
          type: refer('Restio'),
          modifier: FieldModifier.final$,
        ),
        _generateField(
          name: 'baseUri',
          type: refer('String'),
          modifier: FieldModifier.final$,
        ),
      ]);
      // Constructors.
      c.constructors.add(_generateConstructor(baseUri));
      // Implementents.
      c.implements.addAll([refer(className)]);
      // Methods.
      c.methods.addAll(_generateMethods(element, converters));
    });
  }

  static Map<DartType, DartType> _converters(ClassElement element) {
    final res = <DartType, DartType>{};

    final converters = _annotations(element, annotations.Converter);

    for (final a in converters) {
      final type = a.peek('type')?.typeValue;
      final converter = a.peek('converter')?.typeValue;

      if (converter != null && type != null) {
        res[type] = converter;
      }
    }

    return res;
  }

  /// Returns the generated API class' constructor.
  static Constructor _generateConstructor(String baseUri) {
    return Constructor((c) {
      // Parameters.
      c.optionalParameters
          .add(_generateParameter(name: 'client', type: refer('Restio')));

      if (baseUri != null) {
        c.optionalParameters.add(_generateParameter(
            name: 'baseUri', type: refer('String'), named: true));
      } else {
        c.optionalParameters.add(
            _generateParameter(name: 'baseUri', toThis: true, named: true));
      }
      // Initializers.
      c.initializers.addAll([
        refer('client')
            .assign(refer('client')
                .ifNullThen(refer('Restio').newInstance(const [])))
            .code,
        if (baseUri != null) Code("baseUri = baseUri ?? '$baseUri'"),
      ]);
    });
  }

  /// Returns a generic parameter.
  static Parameter _generateParameter({
    String name,
    bool named,
    bool required,
    bool toThis,
    Reference type,
    Code defaultTo,
  }) {
    return Parameter((p) {
      if (name != null) p.name = name;
      if (named != null) p.named = named;
      if (required != null) p.required = required;
      if (toThis != null) p.toThis = toThis;
      if (type != null) p.type = type;
      if (defaultTo != null) p.defaultTo = defaultTo;
    });
  }

  /// Returns a generic field.
  static Field _generateField({
    String name,
    FieldModifier modifier,
    bool static,
    Reference type,
    Code assignment,
  }) {
    return Field((f) {
      if (name != null) f.name = name;
      if (modifier != null) f.modifier = modifier;
      if (static != null) f.static = static;
      if (type != null) f.type = type;
      if (assignment != null) f.assignment = assignment;
    });
  }

  static const _methodAnnotations = [
    annotations.Get,
    annotations.Post,
    annotations.Put,
    annotations.Delete,
    annotations.Head,
    annotations.Patch,
    annotations.Options,
    annotations.Method,
  ];

  /// Checks if the method is valid.
  static bool _isValidMethod(MethodElement m) {
    return m.isAbstract &&
        (m.returnType.isDartAsyncFuture || m.returnType.isDartAsyncStream);
  }

  /// Checks if the method has a @Method annotation.
  static bool _hasMethodAnnotation(MethodElement m) {
    return _methodAnnotation(m) != null;
  }

  /// Checks if the method has an [annotation].
  static bool _hasAnnotation(
    Element m,
    Type annotation,
  ) {
    return _annotation(m, annotation) != null;
  }

  /// Returns the all generated methods.
  static List<Method> _generateMethods(
    ClassElement element,
    Map<DartType, DartType> converters,
  ) {
    return [
      for (final m in element.methods)
        if (_isValidMethod(m) && _hasMethodAnnotation(m))
          _generateMethod(m, converters),
    ];
  }

  /// Returns the generated method for an API endpoint method.
  static Method _generateMethod(
    MethodElement element,
    Map<DartType, DartType> converters,
  ) {
    // The HTTP method annotation.
    final httpMethod = _methodAnnotation(element);

    return Method((m) {
      // Name.
      m.name = element.displayName;
      // Async method.
      m.modifier = element.returnType.isDartStream
          ? MethodModifier.asyncStar
          : MethodModifier.async;
      // Override.
      m.annotations.addAll(const [CodeExpression(Code('override'))]);
      // Parameters.
      m.requiredParameters.addAll(
        element.parameters
            .where((p) => p.isRequiredPositional || p.isRequiredNamed)
            .map(
              (p) => _generateParameter(
                name: p.name,
                named: p.isNamed,
                type: refer(p.type.getDisplayString()),
              ),
            ),
      );

      m.optionalParameters.addAll(
        element.parameters.where((p) => p.isOptional).map(
              (p) => _generateParameter(
                name: p.name,
                named: p.isNamed,
                defaultTo: p.defaultValueCode == null
                    ? null
                    : Code(p.defaultValueCode),
              ),
            ),
      );
      // Body.
      m.body = _generateRequest(element, httpMethod, converters);
      // Return Type.
      m.returns = refer(element.returnType.getDisplayString());
    });
  }

  /// Returns the all parameters from a method with your
  /// first [type] annotation.
  static Map<ParameterElement, ConstantReader> _parametersOfAnnotation(
    MethodElement element,
    Type type,
  ) {
    final annotations = <ParameterElement, ConstantReader>{};

    for (final p in element.parameters) {
      final a = type.toTypeChecker().firstAnnotationOf(p);

      if (a != null) {
        annotations[p] = ConstantReader(a);
      }
    }

    return annotations;
  }

  /// Returns the all parameters from a method with specified [type].
  static List<ParameterElement> _parametersOfType(
    MethodElement element,
    Type type,
  ) {
    final parameters = <ParameterElement>[];

    for (final p in element.parameters) {
      if (p.type.isExactlyType(type)) {
        parameters.add(p);
      }
    }

    return parameters;
  }

  /// Returns the generated path from @Path parameters.
  static Expression _generatePath(
    MethodElement element,
    ConstantReader method,
  ) {
    // Parameters annotated with @Path.
    final paths = _parametersOfAnnotation(element, annotations.Path);
    // Path value from the @Method annotation.
    var path = method.peek("path")?.stringValue ?? '';
    // Replaces the path named-segments by the @Path parameter.
    if (path.isNotEmpty) {
      paths.forEach((p, a) {
        final name = a.peek("name")?.stringValue ?? p.displayName;
        path = path.replaceFirst("{$name}", "\$${p.displayName}");
      });
    }
    // Returns the path as String literal.
    return literal(path);
  }

  static Code _generateRequest(
    MethodElement element,
    ConstantReader method,
    Map<DartType, DartType> converters,
  ) {
    final blocks = <Code>[];

    // Request.
    final requestMethod = _generateRequestMethod(method);
    final requestUri = _generateRequestUri(element, method);
    final requestHeaders = _generateRequestHeaders(element);
    final requestQueries = _generateRequestQueries(element);
    final requestBody = _generateRequestBody(element, converters);
    final requestExtra = _generateRequestExtra(element);
    final requestOptions = _generateRequestOptions(element);
    final response = _generateResponse(element, converters);

    if (requestHeaders != null) {
      blocks.add(requestHeaders);
    }

    if (requestQueries != null) {
      blocks.add(requestQueries);
    }

    if (requestBody is Code) {
      blocks.add(requestBody);
    }

    final request = refer('Request')
        .call(
          const [],
          {
            // Method.
            'method': requestMethod,
            // Uri.
            'uri': requestUri,
            // Headers.
            if (requestHeaders != null)
              'headers': refer('_headers.build').call(const []).expression,
            // Queries.
            if (requestQueries != null)
              'queries': refer('_queries.build').call(const []).expression,
            // Body.
            if (requestBody is Code)
              'body': refer('_form.build').call(const []).expression
            else if (requestBody != null)
              'body': requestBody,
            // Extra.
            if (requestExtra != null)
              'extra': requestExtra,
            // Options.
            if (requestOptions != null)
              'options': requestOptions,
          },
        )
        .assignFinal('_request')
        .statement;
    blocks.add(request);
    // Call.
    final call = refer('client.newCall')
        .call([refer('_request')])
        .assignFinal('_call')
        .statement;
    blocks.add(call);
    // Response.
    blocks.add(response);

    return Block.of(blocks);
  }

  static Expression _generateRequestMethod(ConstantReader method) {
    return literal(method.peek('name')?.stringValue);
  }

  static Expression _generateRequestUri(
    MethodElement element,
    ConstantReader method,
  ) {
    final path = _generatePath(element, method);
    return refer('RequestUri.parse').call(
      [path],
      {
        'baseUri': refer('baseUri').expression,
      },
    ).expression;
  }

  static Code _generateRequestHeaders(MethodElement element) {
    final blocks = <Code>[];

    blocks.add(
      refer('HeadersBuilder')
          .newInstance(const [])
          .assignFinal('_headers')
          .statement,
    );

    for (final a in _annotations(element, annotations.Header)) {
      final name = a.peek('name')?.stringValue;
      final value = a.peek('value')?.stringValue;

      if (name != null &&
          name.isNotEmpty &&
          value != null &&
          value.isNotEmpty) {
        blocks.add(refer('_headers.add')
            .call([literal(name), literal(value)]).statement);
      }
    }

    var headers = _parametersOfAnnotation(element, annotations.Header);

    headers?.forEach((p, a) {
      final name = a.peek('name')?.stringValue ?? p.displayName;
      blocks.add(refer('_headers.add')
          .call([literal(name), literal('\$${p.displayName}')]).statement);
    });

    headers = _parametersOfAnnotation(element, annotations.Headers);

    headers.forEach((p, a) {
      // Map<String, ?>.
      if (p.type.isExactlyType(Map, [String, null])) {
        blocks.add(
            refer('_headers.addMap').call([refer(p.displayName)]).statement);
      }
      // Headers.
      else if (p.type.isExactlyType(restio.Headers)) {
        blocks.add(refer('_headers.addItemList')
            .call([refer(p.displayName)]).statement);
      }
      // List<Header>.
      else if (p.type.isExactlyType(List, [restio.Header])) {
        blocks.add(
            refer('_headers.addAll').call([refer(p.displayName)]).statement);
      } else {
        throw RetrofitError('Invalid parameter type', p);
      }
    });

    if (blocks.length > 1) {
      return Block.of(blocks);
    } else {
      return null;
    }
  }

  static Code _generateRequestQueries(MethodElement element) {
    final blocks = <Code>[];

    blocks.add(
      refer('QueriesBuilder')
          .newInstance(const [])
          .assignFinal('_queries')
          .statement,
    );

    for (final a in _annotations(element, annotations.Query)) {
      final name = a.peek('name')?.stringValue;
      final value = a.peek('value')?.stringValue;

      if (name != null && name.isNotEmpty) {
        blocks.add(refer('_queries.add')
            .call([literal(name), literal(value)]).statement);
      }
    }

    var queries = _parametersOfAnnotation(element, annotations.Query);

    queries.forEach((p, a) {
      final name = a.peek('name')?.stringValue ?? p.displayName;
      blocks.add(refer('_queries.add')
          .call([literal(name), literal('\$${p.displayName}')]).statement);
    });

    queries = _parametersOfAnnotation(element, annotations.Queries);

    queries.forEach((p, a) {
      // Map<String, ?>.
      if (p.type.isExactlyType(Map, [String, null])) {
        blocks.add(
            refer('_queries.addMap').call([refer(p.displayName)]).statement);
      }
      // Queries.
      else if (p.type.isExactlyType(restio.Queries)) {
        blocks.add(refer('_queries.addItemList')
            .call([refer(p.displayName)]).statement);
      }
      // List<Query>.
      else if (p.type.isExactlyType(List, [restio.Query])) {
        blocks.add(
            refer('_queries.addAll').call([refer(p.displayName)]).statement);
      }
      // List<String>.
      else if (p.type.isExactlyType(List, [String])) {
        final map = Method((m) {
          m.lambda = true;
          m.requiredParameters.add(_generateParameter(name: 'item'));
          m.body =
              refer('_queries.add').call([refer('item'), refer(null)]).code;
        });
        blocks.add(const Code(
            '\t\t// ignore: avoid_function_literals_in_foreach_calls'));
        blocks.add(
            refer('${p.displayName}?.forEach').call([map.closure]).statement);
      } else {
        throw RetrofitError('Invalid parameter type', p);
      }
    });

    if (blocks.length > 1) {
      return Block.of(blocks);
    } else {
      return null;
    }
  }

  static dynamic _generateRequestBody(
    MethodElement element,
    Map<DartType, DartType> converters,
  ) {
    // @Multipart.
    final multipart = _multiPartAnnotation(element);

    if (multipart != null) {
      return _generateRequestMultipartBody(element, multipart);
    }

    // @Form.
    final form = _formAnnotation(element);

    if (form != null) {
      return _generateRequestFormBody(element, form);
    }

    // @Body.
    final body = _parametersOfAnnotation(element, annotations.Body);

    if (body.length > 1) {
      throw RetrofitError(
          'Only should have one @Body annotated parameter', element);
    }

    if (body.isNotEmpty) {
      final parameters = body.keys;

      for (final p in parameters) {
        final a = body[p];
        final contentType = _generateMediaType(a);
        final charset = a.peek('charset')?.stringValue;

        final args = {
          if (contentType != null) 'contentType': contentType,
          if (charset != null) 'charset': literal(charset),
        };

        // String, List<int>, Stream<List<int>>, File or RequestBody.
        final type = p.type.isExactlyType(String)
            ? 'string'
            : p.type.isExactlyType(List, [int])
                ? 'bytes'
                : p.type.isExactlyType(Stream, [List, int])
                    ? 'stream'
                    : p.type.isExactlyType(File)
                        ? 'file'
                        : p.type.isExactlyType(restio.RequestBody)
                            ? 'body'
                            : null;

        if (type == null) {
          if (!converters.containsKey(p.type)) {
            throw RetrofitError('Converter not found for $type', element);
          }

          return refer('RequestBody.string').call(
            [
              refer('${converters[p.type]}.encode').call(
                [refer(p.displayName)],
              ).awaited,
            ],
            args,
          );
        } else if (type == 'body') {
          return refer(p.displayName);
        } else {
          return refer('RequestBody.$type').call(
            [refer(p.displayName)],
            args,
          );
        }
      }
    }

    return null;
  }

  static Code _generateRequestFormBody(
    MethodElement element,
    ConstantReader annotation,
  ) {
    final blocks = <Code>[];

    blocks.add(
      refer('FormBuilder').newInstance(const []).assignFinal('_form').statement,
    );

    for (final a in _annotations(element, annotations.Field)) {
      final name = a.peek('name')?.stringValue;
      final value = a.peek('value')?.stringValue;

      if (name != null &&
          name.isNotEmpty &&
          value != null &&
          value.isNotEmpty) {
        blocks.add(
            refer('_form.add').call([literal(name), literal(value)]).statement);
      }
    }

    final fields = _parametersOfAnnotation(element, annotations.Field);

    fields.forEach((p, a) {
      final name = a.peek('name')?.stringValue ?? p.displayName;
      blocks.add(refer('_form.add')
          .call([literal(name), literal('\$${p.displayName}')]).statement);
    });

    final forms = _parametersOfAnnotation(element, annotations.Form);

    forms.forEach((p, a) {
      // Map<String, ?>.
      if (p.type.isExactlyType(Map, [String, null])) {
        blocks
            .add(refer('_form.addMap').call([refer(p.displayName)]).statement);
      }
      // FormBody.
      else if (p.type.isExactlyType(restio.FormBody)) {
        blocks.add(
            refer('_form.addItemList').call([refer(p.displayName)]).statement);
      }
      // List<Field>.
      else if (p.type.isExactlyType(List, [restio.Field])) {
        blocks
            .add(refer('_form.addAll').call([refer(p.displayName)]).statement);
      } else {
        throw RetrofitError('Invalid parameter type', p);
      }
    });

    if (blocks.length > 1) {
      return Block.of(blocks);
    } else {
      return null;
    }
  }

  static Expression _generateRequestMultipartBody(
    MethodElement element,
    ConstantReader annotation,
  ) {
    // @Part.
    var parts = _parametersOfAnnotation(element, annotations.Part);
    final contentType = _generateMediaType(annotation);
    final boundary = annotation.peek('boundary')?.stringValue;
    final charset = annotation.peek('charset')?.stringValue;

    if (parts.isNotEmpty) {
      final values = [];
      final parameters = parts.keys;

      for (final p in parameters) {
        final a = parts[p];

        final displayName = p.displayName;
        final name = a.peek('name')?.stringValue ?? displayName;
        final filename = a.peek('filename')?.stringValue;
        final contentType = _generateMediaType(a);
        final charset = a.peek('charset')?.stringValue;
        Expression part;

        // String.
        if (p.type.isExactlyType(String)) {
          part = refer('Part.form')
              .newInstance([literal(name), literal('\$$displayName')]);
        }
        // File.
        else if (p.type.isExactlyType(File)) {
          part = refer('Part.fromFile').newInstance(
            [
              literal(name),
              refer('$displayName'),
            ],
            {
              'filename': literal(filename),
              if (contentType != null) 'contentType': contentType,
              if (charset != null) 'charset': literal(charset),
            },
          );
        }
        // Part.
        else if (p.type.isExactlyType(restio.Part)) {
          part = refer(displayName);
        }
        // List<Part>.
        else if (p.type.isExactlyType(List, [restio.Part])) {
          part = refer('...$displayName');
        } else {
          throw RetrofitError('Invalid parameter type', p);
        }

        values.add(part);
      }

      return refer('MultipartBody').newInstance(
        const [],
        {
          'parts': literalList(values),
          if (contentType != null) 'contentType': contentType,
          if (boundary != null) 'boundary': literal(boundary),
          if (charset != null) 'charset': literal(charset),
        },
      );
    }

    parts = _parametersOfAnnotation(element, annotations.Multipart);

    if (parts.length > 1) {
      throw RetrofitError(
          'Only should have one @Multipart annotated parameter', element);
    }

    if (parts.isNotEmpty) {
      final parameters = parts.keys;

      for (final p in parameters) {
        final a = parts[p];
        final pContentType = _generateMediaType(a) ?? contentType;
        final pBoundary = a.peek('boundary')?.stringValue ?? boundary;

        // List<Part>.
        if (p.type.isExactlyType(List, [restio.Part])) {
          return refer('MultipartBody').newInstance(
            [],
            {
              'parts': refer(p.displayName),
              if (pContentType != null) 'contentType': pContentType,
              if (pBoundary != null) 'boundary': literal(pBoundary),
            },
          );
        }
        // MultipartBody.
        else if (p.type.isExactlyType(restio.MultipartBody)) {
          return refer(p.displayName);
        }
        // Map<String, ?>.
        else if (p.type.isExactlyType(Map, [String, null])) {
          return refer('MultipartBody.fromMap').call(
            [refer(p.displayName)],
            {
              if (pContentType != null) 'contentType': pContentType,
              if (pBoundary != null) 'boundary': literal(pBoundary),
            },
          );
        } else {
          throw RetrofitError('Invalid parameter type', p);
        }
      }
    }

    return null;
  }

  static Expression _generateRequestExtra(MethodElement element) {
    // @Extra.
    final extra = _parametersOfAnnotation(element, annotations.Extra);

    if (extra.length > 1) {
      throw RetrofitError(
          'Only should have one @Extra annotated parameter', element);
    }

    if (extra.isNotEmpty) {
      final parameters = extra.keys;

      for (final p in parameters) {
        // Map<String, ?>.
        if (p.type.isExactlyType(Map, [String, null])) {
          return refer(p.displayName);
        } else {
          throw RetrofitError('Invalid parameter type', p);
        }
      }
    }

    return null;
  }

  static Expression _generateRequestOptions(MethodElement element) {
    // @Options.
    final options = _parametersOfType(element, restio.RequestOptions);

    if (options.length > 1) {
      throw RetrofitError(
          'Only should have one RequestOption parameter', element);
    }

    final auth = _generateDigestAuth(element) ?? _generateBasicAuth(element);
    final isHttp2 = _hasAnnotation(element, annotations.Http2);
    final params = {
      if (auth != null) 'auth': auth,
      if (isHttp2) 'http2': literalBool(true),
    };

    Expression expr;

    if (options.isNotEmpty && params.isNotEmpty) {
      expr = refer('${options[0].displayName}.copyWith').call(const [], params);
    } else if (options.isNotEmpty) {
      expr = refer(options[0].displayName);
    } else if (params.isNotEmpty) {
      final isConst = auth is ConstExpression || isHttp2;
      expr = isConst
          ? refer('RequestOptions').constInstance(const [], params)
          : refer('RequestOptions').newInstance(const [], params);
    }

    return expr;
  }

  static Expression _generateBasicAuth(MethodElement element) {
    // Method.
    var auth = _annotation(element, annotations.BasicAuth);
    dynamic username = auth?.peek('user')?.stringValue;
    dynamic password = auth?.peek('pass')?.stringValue;
    var type = auth?.peek('type')?.stringValue;

    if (type != null) {
      throw RetrofitError('Invalid BasicAuth annotation', element);
    } else if (username != null && password != null) {
      return ConstExpression(
        refer('BasicAuthenticator').constInstance(const [], {
          'username': literal(username),
          'password': literal(password),
        }),
      );
    }

    // Parameters.
    var auths = _parametersOfAnnotation(element, annotations.BasicAuth);
    final parameters = auths.keys;

    for (final p in parameters) {
      final a = auths[p];
      type = a.peek('type').stringValue;

      if (type == null) {
        throw RetrofitError('Invalid BasicAuth annotation', p);
      } else if (type == 'user' && username != null) {
        throw RetrofitError('Duplicate BasicAuth annotation', p);
      } else if (type == 'pass' && password != null) {
        throw RetrofitError('Duplicate BasicAuth annotation', p);
      }

      switch (type) {
        case 'user':
          username = refer(p.displayName);
          break;
        case 'pass':
          password = refer(p.displayName);
          break;
      }
    }

    if (username != null && password != null) {
      return refer('BasicAuthenticator').newInstance(const [], {
        'username': username is String ? literal(username) : username,
        'password': password is String ? literal(password) : password,
      });
    }

    return null;
  }

  static Expression _generateDigestAuth(MethodElement element) {
    // Method.
    var auth = _annotation(element, annotations.DigestAuth);
    dynamic username = auth?.peek('user')?.stringValue;
    dynamic password = auth?.peek('pass')?.stringValue;
    var type = auth?.peek('type')?.stringValue;

    if (type != null) {
      throw RetrofitError('Invalid DigestAuth annotation', element);
    } else if (username != null && password != null) {
      return ConstExpression(
        refer('DigestAuthenticator').constInstance(const [], {
          'username': literal(username),
          'password': literal(password),
        }),
      );
    }

    // Parameters.
    var auths = _parametersOfAnnotation(element, annotations.DigestAuth);
    final parameters = auths.keys;

    for (final p in parameters) {
      final a = auths[p];
      type = a.peek('type').stringValue;

      if (type == null) {
        throw RetrofitError('Invalid DigestAuth annotation', p);
      } else if (type == 'user' && username != null) {
        throw RetrofitError('Duplicate DigestAuth annotation', p);
      } else if (type == 'pass' && password != null) {
        throw RetrofitError('Duplicate DigestAuth annotation', p);
      }

      switch (type) {
        case 'user':
          username = refer(p.displayName);
          break;
        case 'pass':
          password = refer(p.displayName);
          break;
      }
    }

    if (username != null && password != null) {
      return refer('DigestAuthenticator').newInstance(const [], {
        'username': username is String ? literal(username) : username,
        'password': password is String ? literal(password) : password,
      });
    }

    return null;
  }

  static Block _generateResponseThrows(MethodElement element) {
    final throws = _annotation(element, annotations.Throws);

    final blocks = <Code>[];
    final min = throws?.peek('min')?.intValue ?? 300;
    final max = throws?.peek('max')?.intValue ?? 600;
    final negate = throws?.peek('negate')?.boolValue;

    if (throws != null) {
      blocks.add(
        refer('HttpStatusException.throwsIfBetween').call(
          [
            refer('_response'),
            literal(min),
            literal(max),
          ],
          {
            if (negate == true) 'negate': literal(negate),
          },
        ).statement,
      );
    } else {
      blocks.add(
        refer('HttpStatusException.throwsIfNotSuccess').call(
          [refer('_response')],
        ).statement,
      );
    }

    return Block.of(blocks);
  }

  static Block _generateResponse(
    MethodElement element,
    Map<DartType, DartType> converters,
  ) {
    final isRaw = _hasAnnotation(element, annotations.Raw);
    final blocks = <Code>[];

    blocks.add(
      refer('_call.execute')
          .call(const [])
          .awaited
          .assignFinal('_response')
          .statement,
    );

    final responseThrows = _generateResponseThrows(element);

    if (responseThrows != null) {
      blocks.add(responseThrows);
    }

    final returnType = element.returnType;
    var hasReturn = true;
    var hasYield = false;
    var closeable = true;

    // Nothing.
    if (returnType.isExactlyType(Future, ['void'])) {
      hasReturn = false;
    }
    // Future<String> returns String.
    else if (returnType.isExactlyType(Future, [String])) {
      blocks.add(
        refer('_response.body.string')
            .call(const [])
            .awaited
            .assignFinal('_body')
            .statement,
      );
    }
    // Future<List<int>> returns raw or decompressed data.
    else if (returnType.isExactlyType(Future, [List, int])) {
      blocks.add(
        (isRaw
                ? refer('_response.body.raw')
                : refer('_response.body.decompressed'))
            .call(const [])
            .awaited
            .assignFinal('_body')
            .statement,
      );
    }
    // Future<Response> returns Response.
    else if (returnType.isExactlyType(Future, [restio.Response])) {
      closeable = false;

      if (responseThrows != null) {
        blocks.removeAt(1);
      }

      blocks.add(
        refer('_response').assignFinal('_body').statement,
      );
    }
    // Future<dynamic> returns JSON-decoded data.
    else if (returnType.isExactlyType(Future, ['dynamic'])) {
      blocks.add(
        refer('_response.body.json')
            .call(const [])
            .awaited
            .assignFinal('_body')
            .statement,
      );
    }
    // Stream<List<int>>.
    else if (returnType.isExactlyType(Stream, [List, int])) {
      hasYield = true;
      closeable = false;

      blocks.add(
        refer('_response.body.data').assignFinal('_body').statement,
      );
    }
    // Future<int> returns status code.
    else if (returnType.isExactlyType(Future, [int])) {
      if (responseThrows != null) {
        blocks.removeAt(1);
      }

      blocks.add(
        refer('_response.code').assignFinal('_body').statement,
      );
    }
    // Future<?> or Future<List<?>> return custom object from JSON.
    else if (returnType.isExactlyType(Future, [null]) ||
        returnType.isExactlyType(Future, [List, null])) {
      blocks.add(
        refer('_response.body.string')
            .call(const [])
            .awaited
            .assignFinal('_data')
            .statement,
      );

      final types = returnType.extractTypes();

      if (types.length == 2) {
        final type = types[1];

        if (!converters.containsKey(type)) {
          throw RetrofitError('Converter not found for $type', element);
        }

        blocks.add(
          refer('${converters[type]}.decode')
              .call([refer('_data')])
              .awaited
              .assignFinal('_body')
              .statement,
        );
      } else if (types.length == 3) {
        final type = types[2];

        if (!converters.containsKey(type)) {
          throw RetrofitError('Converter not found for $type', element);
        }

        blocks.add(
          refer('${converters[type]}.decodeList')
              .call([refer('_data')])
              .awaited
              .assignFinal('_body')
              .statement,
        );
      } else {
        throw RetrofitError('Invalid return type', element);
      }
    } else {
      throw RetrofitError('Invalid return type', element);
    }

    if (closeable) {
      blocks.add(refer('_response.close').call(const []).awaited.statement);
    }

    if (hasYield) {
      blocks.add(refer('yield* _body').statement);
    } else if (hasReturn) {
      blocks.add(refer('_body').returned.statement);
    }

    return Block.of(blocks);
  }

  static Expression _generateMediaType(
    ConstantReader annotation, [
    String defaultValue,
  ]) {
    final contentType =
        annotation.peek('contentType')?.stringValue ?? defaultValue;

    switch (contentType?.toLowerCase()) {
      case 'application/x-www-form-urlencoded':
        return refer('MediaType.formUrlEncoded');
      case 'multipart/mixed':
        return refer('MediaType.multipartMixed');
      case 'multipart/alternative':
        return refer('MediaType.multipartAlternative');
      case 'multipart/digest':
        return refer('MediaType.multipartDigest');
      case 'multipart/parallel':
        return refer('MediaType.multipartParallel');
      case 'multipart/form-data':
        return refer('MediaType.multipartFormData');
      case 'application/json':
        return refer('MediaType.json');
      case 'application/octet-stream':
        return refer('MediaType.octetStream');
      case 'text/plain':
        return refer('MediaType.text');
    }

    if (contentType != null) {
      return refer('MediaType.parse').call([refer(contentType)]);
    } else {
      return null;
    }
  }

  static ConstantReader _annotation(
    Element element,
    Type type,
  ) {
    final a = type
        .toTypeChecker()
        .firstAnnotationOf(element, throwOnUnresolved: false);

    if (a != null) {
      return ConstantReader(a);
    } else {
      return null;
    }
  }

  static List<ConstantReader> _annotations(
    Element element,
    Type type,
  ) {
    final a =
        type.toTypeChecker().annotationsOf(element, throwOnUnresolved: false);
    return a?.map((e) => ConstantReader(e))?.toList();
  }

  static ConstantReader _methodAnnotation(MethodElement element) {
    ConstantReader a;

    for (var i = 0; a == null && i < _methodAnnotations.length; i++) {
      a = _annotation(element, _methodAnnotations[i]);
    }

    return a;
  }

  static ConstantReader _formAnnotation(MethodElement element) {
    return _annotation(element, annotations.Form);
  }

  static ConstantReader _multiPartAnnotation(MethodElement element) {
    return _annotation(element, annotations.Multipart);
  }
}

Builder generatorFactoryBuilder(BuilderOptions options) => SharedPartBuilder(
      [RetrofitGenerator()],
      "retrofit",
    );

Builder retrofitBuilder(BuilderOptions options) =>
    generatorFactoryBuilder(options);

extension DartTypeExtension on DartType {
  bool get isDartStream {
    return element != null && element.name == "Stream";
  }

  bool get isDartAsyncStream {
    return isDartStream && element.library.isDartAsync;
  }
}

extension DartTypeExtenstion on DartType {
  TypeChecker toTypeChecker() {
    return TypeChecker.fromStatic(this);
  }

  bool isExactlyType(
    Type type, [
    List types = const [],
  ]) {
    final parameterTypes = extractTypes().sublist(1);

    if (!type.isExactlyType(this)) {
      return false;
    }

    if (parameterTypes.length != types.length) {
      return false;
    }

    for (var i = 0; i < parameterTypes.length; i++) {
      if (types[i] == null) {
        continue;
      } else if (types[i] == 'void') {
        if (!parameterTypes[i].isVoid) {
          return false;
        }
      } else if (types[i] == 'dynamic') {
        if (!parameterTypes[i].isDynamic) {
          return false;
        }
      } else if (types[i] is String || types[i] is! Type) {
        return false;
      } else if (!(types[i] as Type).isExactlyType(parameterTypes[i])) {
        return false;
      }
    }

    return true;
  }

  List<DartType> extractTypes() {
    return _extractTypes(this);
  }

  static List<DartType> _extractTypes(DartType type) {
    if (type is ParameterizedType) {
      return [
        type,
        for (final a in type.typeArguments) ..._extractTypes(a),
      ];
    } else {
      return [type];
    }
  }
}

extension TypeExtension on Type {
  TypeChecker toTypeChecker() {
    return TypeChecker.fromRuntime(this);
  }

  bool isExactlyType(DartType type) {
    return toTypeChecker().isExactlyType(type);
  }
}

class RetrofitError extends InvalidGenerationSourceError {
  RetrofitError(String message, Element element)
      : super(message, element: element);
}
