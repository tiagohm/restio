import 'dart:io';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:restio/src/retrofit/annotations.dart' as annotations;
import 'package:restio/restio.dart';
import 'package:source_gen/source_gen.dart';

// TODO: Retornar o code junto com a resposta.
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
      c.methods.addAll(_generateMethods(element));
    });
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
    MethodElement m,
    Type annotation,
  ) {
    return _annotation(m, annotation) != null;
  }

  /// Returns the all generated methods.
  static List<Method> _generateMethods(ClassElement element) {
    return [
      for (final m in element.methods)
        if (_isValidMethod(m) && _hasMethodAnnotation(m)) _generateMethod(m),
    ];
  }

  /// Returns the generated method for an API endpoint method.
  static Method _generateMethod(MethodElement element) {
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
      m.body = _generateRequest(element, httpMethod);
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

  /// Returns the all parameters from a method with your
  /// first [type] annotation.
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

  /// Returns the generated path from @Path annotated parameters.
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

  /// ```dart
  /// final request = Request(method: 'GET', uri: RequestUri.parse(path));
  /// final call = restio.newCall(request);
  /// final response = await call.execute();
  /// return response;
  /// ```
  static Code _generateRequest(
    MethodElement element,
    ConstantReader method,
  ) {
    final blocks = <Code>[];

    // Request.
    final requestMethod = _generateRequestMethod(method);
    final requestUri = _generateRequestUri(element, method);
    final requestHeaders = _generateRequestHeaders(element);
    final requestQueries = _generateRequestQueries(element);
    final requestBody = _generateRequestBody(element);
    final requestExtra = _generateRequestExtra(element);
    final requestOptions = _generateRequestOptions(element);
    final response = _generateResponse(element);

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
            'method': requestMethod,
            'uri': requestUri,
            if (requestHeaders != null)
              'headers': refer('_headers.build').call(const []).expression,
            if (requestQueries != null)
              'queries': refer('_queries.build').call(const []).expression,
            if (requestBody is Code)
              'body': refer('_form.build').call(const []).expression
            else if (requestBody != null)
              'body': requestBody,
            if (requestExtra != null) 'extra': requestExtra,
            if (requestOptions != null) 'options': requestOptions,
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
      else if (p.type.isExactlyType(Headers)) {
        blocks.add(refer('_headers.addItemList')
            .call([refer(p.displayName)]).statement);
      }
      // List<Header>.
      else if (p.type.isExactlyType(List, [Header])) {
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

      if (name != null &&
          name.isNotEmpty &&
          value != null &&
          value.isNotEmpty) {
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
      else if (p.type.isExactlyType(Queries)) {
        blocks.add(refer('_queries.addItemList')
            .call([refer(p.displayName)]).statement);
      }
      // List<Query>.
      else if (p.type.isExactlyType(List, [Query])) {
        blocks.add(
            refer('_queries.addAll').call([refer(p.displayName)]).statement);
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

  static dynamic _generateRequestBody(MethodElement element) {
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

    if (body.isNotEmpty) {
      final parameters = body.keys;

      for (final p in parameters) {
        final a = body[p];
        final contentType = _generateMediaType(a);
        // String, List<int>, Stream<List<int>>, File.
        final type = p.type.isExactlyType(String)
            ? 'string'
            : p.type.isExactlyType(List, [int])
                ? 'bytes'
                : p.type.isExactlyType(Stream, [List, int])
                    ? 'stream'
                    : p.type.isExactlyType(File) ? 'file' : null;

        if (type != null) {
          return refer('RequestBody.$type').call(
            [refer(p.displayName)],
            {
              if (contentType != null) 'contentType': contentType,
            },
          );
        } else {
          throw RetrofitError('Invalid parameter type', p);
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
      else if (p.type.isExactlyType(FormBody)) {
        blocks.add(
            refer('_form.addItemList').call([refer(p.displayName)]).statement);
      }
      // List<FormItem>.
      else if (p.type.isExactlyType(List, [FormItem])) {
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
        else if (p.type.isExactlyType(Part)) {
          part = refer(displayName);
        }
        // List<Part>.
        else if (p.type.isExactlyType(List, [Part])) {
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
        },
      );
    }

    parts = _parametersOfAnnotation(element, annotations.MultiPart);

    if (parts.length > 1) {
      throw RetrofitError(
          'Only should have one @MultiPart annotated parameter', element);
    }

    if (parts.isNotEmpty) {
      final parameters = parts.keys;

      for (final p in parameters) {
        final a = parts[p];
        final pContentType = _generateMediaType(a) ?? contentType;
        final pBoundary = a.peek('boundary')?.stringValue ?? boundary;

        // List<Part>.
        if (p.type.isExactlyType(List, [Part])) {
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
        else if (p.type.isExactlyType(MultipartBody)) {
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
    final options = _parametersOfType(element, RequestOptions);

    if (options.length > 1) {
      throw RetrofitError(
          'Only should have one RuquestOption parameter', element);
    }

    if (options.isNotEmpty) {
      return refer(options[0].displayName);
    }

    return null;
  }

  static Block _generateResponse(MethodElement element) {
    final isRaw = _hasAnnotation(element, annotations.Raw);
    final blocks = <Code>[];

    blocks.add(
      refer('_call.execute')
          .call(const [])
          .awaited
          .assignFinal('_response')
          .statement,
    );

    final returnType = element.returnType;
    var hasReturn = true;
    var hasYield = false;
    var closeable = true;

    if (returnType.isExactlyType(Future, ['void']) || returnType.isVoid) {
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
    else if (returnType.isExactlyType(Future, [Response])) {
      closeable = false;

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
      blocks.add(
        refer('_response.code').assignFinal('_body').statement,
      );
    }
    // Future<?> or Future<List<?>> return custom object from JSON.
    else if (returnType.isExactlyType(Future, [null]) ||
        returnType.isExactlyType(Future, [List, null])) {
      blocks.add(
        refer('_response.body.json')
            .call(const [])
            .awaited
            .assignFinal('_json')
            .statement,
      );

      final types = returnType.extractTypes();

      if (types.length == 2) {
        blocks.add(
          refer('${types[1].getDisplayString()}.fromJson')
              .call([refer('_json')])
              .assignFinal('_body')
              .statement,
        );
      } else if (types.length == 3) {
        final map = Method((m) {
          m.requiredParameters.add(_generateParameter(name: 'item'));
          m.lambda = true;
          m.body = refer('${types[2].getDisplayString()}.fromJson')
              .call([refer('item')]).code;
        });

        blocks.add(
          refer('_json.map').call([map.closure]).assignFinal('_body').statement,
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
    MethodElement element,
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
    MethodElement element,
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
    return _annotation(element, annotations.MultiPart);
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
