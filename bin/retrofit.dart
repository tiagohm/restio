import 'dart:io';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:restio/src/retrofit/annotations.dart' as annotations;
import 'package:restio/restio.dart';
import 'package:source_gen/source_gen.dart';

// TODO: Melhorar o uso do método isExactlyType.
class RetrofitGenerator extends GeneratorForAnnotation<annotations.Api> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // Must be a class.
    if (element is! ClassElement) {
      final name = element.displayName;
      throw InvalidGenerationSourceError('Generator cannot target `$name`.');
    }

    return _generate(element, annotation);
  }

  static String _generate(
    Element element,
    ConstantReader annotation,
  ) {
    final classBuilder = Class((c) => _generateClass(element, annotation, c));
    final emitter = DartEmitter();
    return DartFormatter().format('${classBuilder.accept(emitter)}');
  }

  static void _generateClass(
    Element element,
    ConstantReader annotation,
    ClassBuilder builder,
  ) {
    final className = element.name;
    final name = '_$className';
    final baseUri = annotation.peek('baseUri')?.stringValue;

    // Class name.
    builder.name = name;

    // Fields.
    builder.fields.addAll([
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
    builder.constructors
        .add(Constructor((c) => _generateConstructor(baseUri, c)));

    // Implementents.
    builder.implements.addAll([refer(className)]);

    // Methods.
    builder.methods.addAll(_generateMethods(element));
  }

  static void _generateConstructor(
    String baseUri,
    ConstructorBuilder builder,
  ) {
    // Parameters.
    builder.optionalParameters
        .add(_generateParameter(name: 'client', type: refer('Restio')));
    if (baseUri != null) {
      builder.optionalParameters.add(_generateParameter(
          name: 'baseUri', type: refer('String'), named: true));
    } else {
      builder.optionalParameters
          .add(_generateParameter(name: 'baseUri', toThis: true, named: true));
    }
    // Initializers.
    builder.initializers.addAll([
      refer('client')
          .assign(
              refer('client').ifNullThen(refer('Restio').newInstance(const [])))
          .code,
      if (baseUri != null) Code("baseUri = baseUri ?? '$baseUri'"),
    ]);
  }

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

  static bool _hasMethodAnnotation(MethodElement m) {
    final a = _methodAnnotation(m);
    return a != null &&
        m.isAbstract &&
        (m.returnType.isDartAsyncFuture || m.returnType.isDartAsyncStream);
  }

  static List<Method> _generateMethods(ClassElement element) {
    return [
      for (final m in element.methods)
        if (_hasMethodAnnotation(m)) _generateMethod(m),
    ];
  }

  static Method _generateMethod(MethodElement element) {
    final httpMethod = _methodAnnotation(element);

    return Method((m) {
      m.name = element.displayName;
      m.modifier = MethodModifier.async;
      m.annotations.addAll(const [CodeExpression(Code('override'))]);

      m.requiredParameters.addAll(
        element.parameters
            .where((p) => p.isRequiredPositional || p.isRequiredNamed)
            .map((p) => _generateParameter(
                name: p.name,
                named: p.isNamed,
                type: refer(p.type.getDisplayString()))),
      );

      m.optionalParameters.addAll(
        element.parameters.where((p) => p.isOptional).map((p) =>
            _generateParameter(
                name: p.name,
                named: p.isNamed,
                defaultTo: p.defaultValueCode == null
                    ? null
                    : Code(p.defaultValueCode))),
      );

      m.body = _generateRequest(element, httpMethod);
    });
  }

  static Map<ParameterElement, ConstantReader> _annotations(
    MethodElement m,
    Type type,
  ) {
    final res = <ParameterElement, ConstantReader>{};

    for (final p in m.parameters) {
      final a = type.firstAnnotationOf(p);

      if (a != null) {
        res[p] = ConstantReader(a);
      }
    }

    return res;
  }

  // Gera a URI usando os @Path encontrados nos parâmetros.
  static Expression _generatePath(
    MethodElement element,
    ConstantReader method,
  ) {
    final paths = _annotations(element, annotations.Path);
    var path = method.peek("path")?.stringValue ?? '';

    if (path.isNotEmpty) {
      paths.forEach((field, a) {
        final name = a.peek("name")?.stringValue ?? field.displayName;
        path = path.replaceFirst("{$name}", "\$${field.displayName}");
      });
    }

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

    if (requestHeaders != null) {
      blocks.add(requestHeaders);
    }

    if (requestQueries != null) {
      blocks.add(requestQueries);
    }

    final request = refer('Request')
        .call(
          const [],
          {
            'method': requestMethod,
            'uri': requestUri,
            if (requestHeaders != null)
              'headers': refer('_hb.build').call(const []).expression,
            if (requestQueries != null)
              'queries': refer('_qb.build').call(const []).expression,
            if (requestBody != null) 'body': requestBody,
          },
        )
        .assignFinal('request')
        .statement;
    blocks.add(request);
    // Call.

    // Response.

    return Block.of(blocks);
  }

  static Expression _generateRequestMethod(ConstantReader method) {
    return literal(method.peek('name').stringValue);
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

  // TODO: Header com valor padrão, caso o parâmetro seja nulo.
  // TODO: Passar Header no método, necessita do TODO acima.
  static Code _generateRequestHeaders(MethodElement element) {
    final blocks = <Code>[];

    blocks.add(refer('HeadersBuilder')
        .newInstance(const [])
        .assignFinal('_hb')
        .statement);

    // @Param.
    var params = _annotations(element, annotations.Header);

    if (params.isNotEmpty) {
      final fields = params.keys;

      for (final field in fields) {
        final a = params[field];

        final name = a.peek('name')?.stringValue ?? field.displayName;
        blocks.add(refer('_hb.add').call(
            [literal(name), literal('\$${field.displayName}')]).statement);
      }
    }

    // @List.
    params = _annotations(element, annotations.Headers);

    // TODO: Exibir aviso de que apenas um parâmetro pode ser anotado com @Form.

    if (params.isNotEmpty) {
      final fields = params.keys;

      for (final field in fields) {
        if ((Map).isExactlyType(field.type)) {
          blocks.add(
              refer('_hb.addMap').call([refer(field.displayName)]).statement);
        } else if ((Headers).isExactlyType(field.type)) {
          blocks.add(refer('_hb.addItemList')
              .call([refer(field.displayName)]).statement);
        } else if ((List).isExactlyType(field.type)) {
          blocks.add(
              refer('_hb.addAll').call([refer(field.displayName)]).statement);
        } else {
          // TODO:
        }
      }
    }

    if (blocks.length > 1) {
      return Block.of(blocks);
    } else {
      return null;
    }
  }

  // TODO: Query com valor padrão, caso o parâmetro seja nulo.
  // TODO: Passar Query no método, necessita do TODO acima.
  static Code _generateRequestQueries(MethodElement element) {
    final blocks = <Code>[];

    blocks.add(refer('QueriesBuilder')
        .newInstance(const [])
        .assignFinal('_qb')
        .statement);

    // @Param.
    var params = _annotations(element, annotations.Query);

    if (params.isNotEmpty) {
      final fields = params.keys;

      for (final field in fields) {
        final a = params[field];

        final name = a.peek('name')?.stringValue ?? field.displayName;
        blocks.add(refer('_qb.add').call(
            [literal(name), literal('\$${field.displayName}')]).statement);
      }
    }

    // @List.
    params = _annotations(element, annotations.Queries);

    // TODO: Exibir aviso de que apenas um parâmetro pode ser anotado com @Form.

    if (params.isNotEmpty) {
      final fields = params.keys;

      for (final field in fields) {
        if ((Map).isExactlyType(field.type)) {
          blocks.add(
              refer('_qb.addMap').call([refer(field.displayName)]).statement);
        } else if ((Queries).isExactlyType(field.type)) {
          blocks.add(refer('_qb.addItemList')
              .call([refer(field.displayName)]).statement);
        } else if ((List).isExactlyType(field.type)) {
          blocks.add(
              refer('_qb.addAll').call([refer(field.displayName)]).statement);
        } else {
          // TODO:
        }
      }
    }

    if (blocks.length > 1) {
      return Block.of(blocks);
    } else {
      return null;
    }
  }

  static Expression _generateRequestBody(MethodElement element) {
    // @Body. (Parameter) (File, String, List<int>, Stream<List<int>>)
    // @Multipart (Method, Parameter) (Multipart)
    // @Part (Parameter) (Primitive, File)
    // @Form (Method, Parameter) (Multipart)
    // @Field (Parameter) (Primitive)

    final multipart = _multiPartAnnotation(element);

    if (multipart != null) {
      // return _generateRequestMultiPartBody(element, multipart);
    }

    final form = _formAnnotation(element);

    if (form != null) {
      return _generateRequestFormBody(element, form);
    }

    final body = _annotations(element, annotations.Body);

    if (body != null && body.isNotEmpty) {
      final fields = body.keys;

      for (final field in fields) {
        final a = body[field];
        final contentType = _generateMediaType(a);
        final type = (String).isExactlyType(field.type)
            ? 'string'
            : (List).isExactlyType(field.type)
                ? 'bytes'
                : (Stream).isExactlyType(field.type)
                    ? 'stream'
                    : (File).isExactlyType(field.type) ? 'file' : null;

        if (type != null) {
          return refer('RequestBody.$type').call(
            [refer(field.displayName)],
            {
              if (contentType != null) 'contentType': contentType,
            },
          );
        } else {
          // TODO: throw
        }
      }
    }

    return null;
  }

  static Expression _generateRequestFormBody(
    MethodElement element,
    ConstantReader annotation,
  ) {
    var list = _annotations(element, annotations.Field);

    if (list.isNotEmpty) {
      final values = [];
      final fields = list.keys;

      for (final field in fields) {
        final a = list[field];

        final name = a.peek('name')?.stringValue ?? field.displayName;
        final header = refer('FormItem')
            .newInstance([literal(name), literal('\$${field.displayName}')]);
        values.add(header);
      }

      return refer('FormBody').newInstance(
        const [],
        {
          'items': literalList(values),
        },
      );
    }

    list = _annotations(element, annotations.Form);

    // TODO: Exibir aviso de que apenas um parâmetro pode ser anotado com @Form.

    if (list.isNotEmpty) {
      final fields = list.keys;

      for (final field in fields) {
        if ((Map).isExactlyType(field.type)) {
          return refer('FormBody.fromMap').call([refer(field.displayName)]);
        } else if ((FormBody).isExactlyType(field.type)) {
          return refer(field.displayName);
        } else {
          // TODO:
        }
      }
    }

    return null;
  }

  static Expression _generateMediaType(ConstantReader annotation) {
    final contentType = annotation.peek('contentType')?.stringValue;

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

  static ConstantReader _findAnnotation(
    MethodElement element,
    Type type,
  ) {
    final a = type.firstAnnotationOf(element, throwOnUnresolved: false);

    if (a != null) {
      return ConstantReader(a);
    } else {
      return null;
    }
  }

  static ConstantReader _methodAnnotation(MethodElement element) {
    ConstantReader a;

    for (var i = 0; a == null && i < _methodAnnotations.length; i++) {
      a = _findAnnotation(element, _methodAnnotations[i]);
    }

    return a;
  }

  static ConstantReader _formAnnotation(MethodElement element) {
    return _findAnnotation(element, annotations.Form);
  }

  static ConstantReader _multiPartAnnotation(MethodElement element) {
    return _findAnnotation(element, annotations.MultiPart);
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

extension TypeExtension on Type {
  TypeChecker toTypeChecker() {
    return TypeChecker.fromRuntime(this);
  }

  bool isExactlyType(DartType type) {
    return toTypeChecker().isExactlyType(type);
  }

  DartObject firstAnnotationOf(
    Element element, {
    bool throwOnUnresolved,
  }) {
    return toTypeChecker()
        .firstAnnotationOf(element, throwOnUnresolved: throwOnUnresolved);
  }
}
