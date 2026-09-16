// Generates Dart types in packages/stacflow/lib/src/generated/ from the
// contracts/ tree (dev-plan D2). Deterministic: same inputs, byte-identical
// output. CI regenerates and fails on drift. Never edit the generated files.
//
// Run from the workspace root:  dart run tool/contracts_gen.dart
import 'dart:convert';
import 'dart:io';

import 'package:yaml/yaml.dart';

const _outDir = 'packages/stacflow/lib/src/generated';

const _header = '''
// GENERATED CODE - DO NOT EDIT.
// Source: contracts/ - regenerate with `dart run tool/contracts_gen.dart`.
// coverage:ignore-file
''';

// JSON-Schema primitives ($defs / components) that map straight to Dart types.
const _primRefs = <String, String>{
  'Seq': 'int',
  'TurnId': 'String',
  'ThreadId': 'String',
  'MessageId': 'String',
  'ToolCallId': 'String',
  'AgentVersionId': 'String',
  'ManifestHash': 'String',
};

Map<String, dynamic> _asMap(Object? o) =>
    (o! as Map).map((k, v) => MapEntry(k as String, v));

String _pascal(String s) => s
    .split(RegExp(r'[_\-]'))
    .where((p) => p.isNotEmpty)
    .map((p) => p[0].toUpperCase() + p.substring(1))
    .join();

String _camel(String s) {
  final p = _pascal(s);
  return p[0].toLowerCase() + p.substring(1);
}

String _refName(String ref) => ref.split('/').last;

/// Collects enums discovered while walking schemas so they emit once.
class EnumReg {
  final Map<String, List<String>> enums = {}; // name -> wire values
  String register(String name, List<String> values) {
    final existing = enums[name];
    if (existing != null && existing.join(',') != values.join(',')) {
      throw StateError('enum name collision: $name');
    }
    enums[name] = values;
    return name;
  }

  String emit() {
    final b = StringBuffer();
    for (final e in enums.entries) {
      b.writeln('enum ${e.key} {');
      for (final v in e.value) {
        b.writeln("  ${_camel(v)}('$v'),");
      }
      b.writeln(';\n');
      b.writeln('  const ${e.key}(this.wire);');
      b.writeln('  final String wire;');
      b.writeln('  static ${e.key} fromWire(String wire) =>');
      b.writeln('      values.firstWhere((v) => v.wire == wire);');
      b.writeln('}\n');
    }
    return b.toString();
  }
}

/// One field of a generated class.
class Field {
  Field(this.wire, this.type, {required this.required, this.kind = 'plain'});
  final String wire; // wire key
  final String type; // dart type WITHOUT nullability suffix
  final bool required;
  final String kind; // plain | enumT | classT | jsonMap | list:<inner-kind>
  String get name => _camel(wire);
  String get dartType => required ? type : '$type?';
}

class ClassSpec {
  ClassSpec(
    this.name,
    this.fields, {
    this.extendsName,
    this.consts = const {},
    this.doc,
  });
  final String name;
  final List<Field> fields;
  final String? extendsName;
  final Map<String, String> consts; // wire key -> const value (discriminators)
  final String? doc;
}

String _emitClass(ClassSpec c) {
  final b = StringBuffer();
  if (c.doc != null) b.writeln('/// ${c.doc}');
  final ext = c.extendsName != null ? ' extends ${c.extendsName}' : '';
  b.writeln('final class ${c.name}$ext {');
  // ctor
  b.writeln('  const ${c.name}({');
  for (final f in c.fields) {
    b.writeln(
      f.required ? '    required this.${f.name},' : '    this.${f.name},',
    );
  }
  b.writeln('  });\n');
  // fromJson
  b.writeln(
    '  factory ${c.name}.fromJson(Map<String, dynamic> json) => ${c.name}(',
  );
  for (final f in c.fields) {
    b.writeln('        ${f.name}: ${_decodeExpr(f)},');
  }
  b.writeln('      );\n');
  // fields
  for (final f in c.fields) {
    b.writeln('  final ${f.dartType} ${f.name};');
  }
  for (final e in c.consts.entries) {
    // Values are stored as Dart literals ("'text'" or "1").
    final type = e.value.startsWith("'") ? 'String' : 'int';
    b.writeln('  $type get ${_camel(e.key)} => ${e.value};');
  }
  b.writeln();
  // toJson
  b.writeln('  Map<String, dynamic> toJson() => <String, dynamic>{');
  for (final e in c.consts.entries) {
    b.writeln("        '${e.key}': ${e.value},");
  }
  for (final f in c.fields.where((f) => f.required)) {
    b.writeln("        '${f.wire}': ${_encodeExpr(f)},");
  }
  b.writeln('      }');
  for (final f in c.fields.where((f) => !f.required)) {
    b.writeln('    ..addAll(${f.name} == null');
    b.writeln('        ? const <String, dynamic>{}');
    b.writeln("        : <String, dynamic>{'${f.wire}': ${_encodeExpr(f)}})");
  }
  b.writeln('      ;');
  b.writeln('}\n');
  return b.toString();
}

String _decodeExpr(Field f) {
  final j = "json['${f.wire}']";
  switch (f.kind) {
    case 'enumT':
      return f.required
          ? '${f.type}.fromWire($j as String)'
          : '$j == null ? null : ${f.type}.fromWire($j as String)';
    case 'classT':
      return f.required
          ? '${f.type}.fromJson(($j as Map).cast<String, dynamic>())'
          : '$j == null ? null : ${f.type}.fromJson(($j as Map).cast<String, dynamic>())';
    case 'jsonMap':
      return f.required
          ? '($j as Map).cast<String, dynamic>()'
          : '($j as Map?)?.cast<String, dynamic>()';
    // NOTE: .cast() views are LAZY - a wrong element type would escape
    // SseEvent.decode's try/catch and throw on first read, breaking the
    // never-throw guarantee. .from() copies and checks eagerly.
    case 'mapInt':
      return f.required
          ? 'Map<String, int>.from($j as Map)'
          : '$j == null ? null : Map<String, int>.from($j as Map)';
    case 'listString':
      return f.required
          ? 'List<String>.from($j as List)'
          : '$j == null ? null : List<String>.from($j as List)';
    case 'listJsonMap':
      return f.required
          ? '($j as List).map((e) => (e as Map).cast<String, dynamic>()).toList()'
          : '($j as List?)?.map((e) => (e as Map).cast<String, dynamic>()).toList()';
    default:
      if (f.kind.startsWith('listClass:')) {
        final inner = f.kind.substring(10);
        final expr =
            '($j as List).map((e) => $inner.fromJson((e as Map).cast<String, dynamic>())).toList()';
        return f.required ? expr : '$j == null ? null : $expr';
      }
      if (f.kind.startsWith('mapClass:')) {
        final v = f.kind.substring(9);
        final expr =
            '($j as Map).map((k, v) => MapEntry(k as String, $v.fromJson((v as Map).cast<String, dynamic>())))';
        return f.required ? expr : '$j == null ? null : $expr';
      }
      return f.required ? '$j as ${f.type}' : '$j as ${f.type}?';
  }
}

String _encodeExpr(Field f) {
  final n = f.name;
  final bang = f.required ? '' : '!';
  switch (f.kind) {
    case 'enumT':
      return '$n$bang.wire';
    case 'classT':
      return '$n$bang.toJson()';
    default:
      if (f.kind.startsWith('listClass:')) {
        return '$n$bang.map((e) => e.toJson()).toList()';
      }
      if (f.kind.startsWith('mapClass:')) {
        return '$n$bang.map((k, v) => MapEntry(k, v.toJson()))';
      }
      return n;
  }
}

/// Resolves a schema node into a [Field]. Registers inline enums under
/// `owner` + field name; resolves $refs against prims, enums, or classes.
Field _fieldFor(
  String owner,
  String wire,
  Map<String, dynamic> schema, {
  required bool required,
  required EnumReg enums,
  required Set<String> classNames,
  required void Function(String name, Map<String, dynamic> schema) onAnon,
}) {
  final ref = schema[r'$ref'] as String?;
  if (ref != null) {
    final name = _refName(ref);
    final prim = _primRefs[name];
    if (prim != null) return Field(wire, prim, required: required);
    if (name == 'FailureClass') {
      return Field(wire, 'FailureClass', required: required, kind: 'enumT');
    }
    return Field(wire, name, required: required, kind: 'classT');
  }
  final enumVals = schema['enum'] as List?;
  if (enumVals != null) {
    final name = enums.register(owner + _pascal(wire), enumVals.cast<String>());
    return Field(wire, name, required: required, kind: 'enumT');
  }
  var type = schema['type'];
  var nullable = false;
  if (type is List) {
    nullable = type.contains('null');
    type = type.firstWhere((t) => t != 'null');
  }
  final isRequired = required && !nullable;
  switch (type) {
    case 'string':
      return Field(wire, 'String', required: isRequired);
    case 'integer':
      return Field(wire, 'int', required: isRequired);
    case 'number':
      return Field(wire, 'double', required: isRequired);
    case 'boolean':
      return Field(wire, 'bool', required: isRequired);
    case 'array':
      final items = _asMap(schema['items'] ?? <String, dynamic>{});
      final itemRef = items[r'$ref'] as String?;
      if (itemRef != null) {
        final n = _refName(itemRef);
        final prim = _primRefs[n];
        if (prim == 'String') {
          return Field(
            wire,
            'List<String>',
            required: isRequired,
            kind: 'listString',
          );
        }
        return Field(
          wire,
          'List<$n>',
          required: isRequired,
          kind: 'listClass:$n',
        );
      }
      if (items['type'] == 'string') {
        return Field(
          wire,
          'List<String>',
          required: isRequired,
          kind: 'listString',
        );
      }
      return Field(
        wire,
        'List<Map<String, dynamic>>',
        required: isRequired,
        kind: 'listJsonMap',
      );
    case 'object':
    default:
      final props = schema['properties'];
      if (props != null) {
        final anonName = owner + _pascal(wire);
        onAnon(anonName, schema);
        return Field(wire, anonName, required: isRequired, kind: 'classT');
      }
      final addl = schema['additionalProperties'];
      if (addl is Map) {
        final a = _asMap(addl);
        if (a['type'] == 'integer') {
          return Field(
            wire,
            'Map<String, int>',
            required: isRequired,
            kind: 'mapInt',
          );
        }
        if (a['properties'] != null) {
          final anonName = '$owner${_pascal(wire)}Value';
          onAnon(anonName, a);
          return Field(
            wire,
            'Map<String, $anonName>',
            required: isRequired,
            kind: 'mapClass:$anonName',
          );
        }
      }
      return Field(
        wire,
        'Map<String, dynamic>',
        required: isRequired,
        kind: 'jsonMap',
      );
  }
}

ClassSpec _classFromObjectSchema(
  String name,
  Map<String, dynamic> schema, {
  required EnumReg enums,
  required Set<String> classNames,
  required List<ClassSpec> sink,
  String? extendsName,
}) {
  final props = _asMap(schema['properties'] ?? <String, dynamic>{});
  final required = ((schema['required'] as List?) ?? const <dynamic>[])
      .cast<String>()
      .toSet();
  final fields = <Field>[];
  final consts = <String, String>{};
  props.forEach((wire, raw) {
    final p = _asMap(raw);
    final constVal = p['const'];
    if (constVal is String) {
      consts[wire] = "'$constVal'";
      return;
    }
    if (constVal is int) {
      consts[wire] = '$constVal';
      return;
    }
    fields.add(
      _fieldFor(
        name,
        wire,
        p,
        required: required.contains(wire),
        enums: enums,
        classNames: classNames,
        onAnon: (n, s) {
          if (classNames.add(n)) {
            sink.add(
              _classFromObjectSchema(
                n,
                s,
                enums: enums,
                classNames: classNames,
                sink: sink,
              ),
            );
          }
        },
      ),
    );
  });
  return ClassSpec(
    name,
    fields,
    extendsName: extendsName,
    consts: consts,
    doc: null,
  );
}

// ───────────────────────── sse_events.dart ─────────────────────────

String _genSse(Map<String, dynamic> doc) {
  final defs = _asMap(doc[r'$defs']);
  final events = _asMap(
    _asMap(doc['x-stacflow-protocol'])['events'],
  ); // name -> $ref
  final enums = EnumReg()
    ..register(
      'FailureClass',
      (_asMap(defs['FailureClass'])['enum'] as List).cast<String>(),
    );
  final classNames = <String>{};
  final sink = <ClassSpec>[];

  // Upstream (shared attribution object).
  sink.add(
    _classFromObjectSchema(
      'Upstream',
      _asMap(defs['Upstream']),
      enums: enums,
      classNames: classNames,
      sink: sink,
    ),
  );

  final decodeCases = <String, String>{}; // event name -> expression
  final classes = <ClassSpec>[];
  final toolCallVariants = <String, String>{}; // phase -> class name

  events.forEach((eventName, refRaw) {
    final defName = _refName(refRaw as String);
    final def = _asMap(defs[defName]);
    final oneOf = def['oneOf'] as List?;
    if (oneOf != null) {
      for (final vRaw in oneOf) {
        final v = _asMap(vRaw);
        final phase =
            _asMap(_asMap(v['properties'])['phase'])['const'] as String;
        final vName = 'ToolCall${_pascal(phase)}Event';
        toolCallVariants[phase] = vName;
        classes.add(
          _classFromObjectSchema(
            vName,
            v,
            enums: enums,
            classNames: classNames,
            sink: sink,
            extendsName: 'ToolCallEvent',
          ),
        );
      }
      decodeCases[eventName] = 'ToolCallEvent.fromJson(data)';
    } else {
      classes.add(
        _classFromObjectSchema(
          defName,
          def,
          enums: enums,
          classNames: classNames,
          sink: sink,
          extendsName: 'SseEvent',
        ),
      );
      decodeCases[eventName] = '$defName.fromJson(data)';
    }
  });

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln(
      '/// The StacFlow SSE protocol v1 (contracts/sse-events.schema.json).',
    )
    ..writeln('///')
    ..writeln(
      '/// `SseEvent.decode` NEVER throws: unknown event names and payloads that',
    )
    ..writeln(
      '/// fail to decode become [SseUnknownEvent] - the additive-evolution',
    )
    ..writeln(
      '/// compatibility mechanism. Local-mode provider adapters emit this same',
    )
    ..writeln('/// union, so cloud and local modes share one event grammar.')
    ..writeln('library;\n')
    ..writeln('sealed class SseEvent {')
    ..writeln('  const SseEvent();')
    ..writeln('  int get seq;\n')
    ..writeln('  /// Decodes one SSE frame. Never throws.')
    ..writeln(
      '  static SseEvent decode(String event, Map<String, dynamic> data) {',
    )
    ..writeln('    try {')
    ..writeln('      return switch (event) {');
  decodeCases.forEach((name, expr) {
    b.writeln("        '$name' => $expr,");
  });
  b
    ..writeln('        _ => SseUnknownEvent(event, data),')
    ..writeln('      };')
    ..writeln('    } on Object {')
    ..writeln('      return SseUnknownEvent(event, data);')
    ..writeln('    }')
    ..writeln('  }')
    ..writeln('}\n')
    ..writeln(
      '/// Passthrough for event names or shapes this build does not know.',
    )
    ..writeln('final class SseUnknownEvent extends SseEvent {')
    ..writeln('  const SseUnknownEvent(this.event, this.data);')
    ..writeln('  final String event;')
    ..writeln('  final Map<String, dynamic> data;')
    ..writeln('  @override')
    ..writeln("  int get seq => data['seq'] is int ? data['seq'] as int : -1;")
    ..writeln('}\n')
    ..writeln('sealed class ToolCallEvent extends SseEvent {')
    ..writeln('  const ToolCallEvent();')
    ..writeln('  String get toolCallId;\n')
    ..writeln('  factory ToolCallEvent.fromJson(Map<String, dynamic> json) =>')
    ..writeln("      switch (json['phase'] as String) {");
  toolCallVariants.forEach((phase, cls) {
    b.writeln("        '$phase' => $cls.fromJson(json),");
  });
  b
    ..writeln(
      "        final other => throw FormatException('unknown phase: \$other'),",
    )
    ..writeln('      };')
    ..writeln('}\n')
    ..writeln(enums.emit());
  for (final c in [...sink, ...classes]) {
    // Event classes need @override on seq / toolCallId getters via fields:
    b.writeln(_emitClass(_overrideMarkers(c)));
  }
  return b.toString();
}

/// Adds `@override`-safe naming: seq and toolCallId are declared as getters on
/// the sealed parents; fields satisfy them automatically in Dart, so nothing
/// to rewrite - kept as a seam for future adjustments.
ClassSpec _overrideMarkers(ClassSpec c) => c;

// ───────────────────────── error_codes.dart ─────────────────────────

String _genErrorCodes(Map<String, dynamic> doc) {
  final codes = _asMap(doc['codes']);
  final b = StringBuffer()
    ..writeln(_header)
    ..writeln("import 'sse_events.dart';\n")
    ..writeln(
      '/// One entry of the error-code registry (contracts/error-codes.json).',
    )
    ..writeln('final class ErrorCodeInfo {')
    ..writeln('  const ErrorCodeInfo({')
    ..writeln('    required this.failureClass,')
    ..writeln('    required this.http,')
    ..writeln('    required this.retryable,')
    ..writeln('    required this.description,')
    ..writeln('  });')
    ..writeln('  final FailureClass failureClass;')
    ..writeln('  final int http;')
    ..writeln('  final bool retryable;')
    ..writeln('  final String description;')
    ..writeln('}\n')
    ..writeln('/// The frozen, additively growing error-code registry.')
    ..writeln('abstract final class ErrorCodes {');
  codes.forEach((code, _) {
    b.writeln("  static const String ${_camel(code)} = '$code';");
  });
  b
    ..writeln()
    ..writeln('  static const Map<String, ErrorCodeInfo> registry = {');
  codes.forEach((code, raw) {
    final c = _asMap(raw);
    final fc = _camel(c['failure_class'] as String);
    final desc = (c['description'] as String).replaceAll("'", r"\'");
    b
      ..writeln("    '$code': ErrorCodeInfo(")
      ..writeln('      failureClass: FailureClass.$fc,')
      ..writeln("      http: ${c['http']},")
      ..writeln("      retryable: ${c['retryable']},")
      ..writeln("      description: '$desc',")
      ..writeln('    ),');
  });
  b
    ..writeln('  };')
    ..writeln('}');
  return b.toString();
}

// ───────────────────────── rest_models.dart / api_paths.dart ─────────────────────────

String _genRestModels(Map<String, dynamic> api) {
  final schemas = _asMap(_asMap(api['components'])['schemas']);
  final enums = EnumReg();
  final classNames = <String>{};
  final sink = <ClassSpec>[];
  final classes = <ClassSpec>[];
  final sealedParents = StringBuffer();

  schemas.forEach((name, raw) {
    final s = _asMap(raw);
    if (_primRefs.containsKey(name)) return; // string prims
    if (name == 'FailureClass') return; // shared with sse_events.dart
    final oneOf = s['oneOf'] as List?;
    if (oneOf != null) {
      final disc = _asMap(s['discriminator']);
      final prop = disc['propertyName'] as String;
      final mapping = _asMap(disc['mapping'])
          .map((k, v) => MapEntry(k, _refName(v as String)));
      sealedParents
        ..writeln('sealed class $name {')
        ..writeln('  const $name();\n')
        ..writeln('  factory $name.fromJson(Map<String, dynamic> json) =>')
        ..writeln("      switch (json['$prop'] as String?) {");
      mapping.forEach((wire, cls) {
        sealedParents.writeln("        '$wire' => $cls.fromJson(json),");
      });
      sealedParents
        ..writeln('        _ => Unknown$name(json),')
        ..writeln('      };\n')
        ..writeln('  Map<String, dynamic> toJson();')
        ..writeln('}\n')
        ..writeln(
          '/// Passthrough for part types this build does not know (additive).',
        )
        ..writeln('final class Unknown$name extends $name {')
        ..writeln('  const Unknown$name(this.json);')
        ..writeln('  final Map<String, dynamic> json;')
        ..writeln('  @override')
        ..writeln('  Map<String, dynamic> toJson() => json;')
        ..writeln('}\n');
      return;
    }
    if (s['enum'] != null) {
      enums.register(name, (s['enum'] as List).cast<String>());
      return;
    }
    if (s['type'] == 'string') return; // patterned string prims (ids)
    var parent = _parentFor(name, schemas);
    classes.add(
      _classFromObjectSchema(
        name,
        s,
        enums: enums,
        classNames: classNames,
        sink: sink,
        extendsName: parent,
      ),
    );
  });

  final b = StringBuffer()
    ..writeln(_header)
    ..writeln('/// REST component models (contracts/rest-api.openapi.yaml).')
    ..writeln(
      '/// Request/response envelopes inline in path definitions are shaped by',
    )
    ..writeln('/// the transport layer; only named components are generated.')
    ..writeln('library;\n')
    ..writeln("import 'sse_events.dart' show FailureClass;\n")
    ..writeln(enums.emit())
    ..writeln(sealedParents);
  for (final c in [...sink, ...classes]) {
    b.writeln(_emitClass(c));
  }
  return b.toString();
}

/// Which oneOf parent (if any) a component belongs to, via discriminator maps.
String? _parentFor(String name, Map<String, dynamic> schemas) {
  String? found;
  schemas.forEach((parent, raw) {
    final s = _asMap(raw);
    if (s['oneOf'] == null) return;
    final mapping = _asMap(_asMap(s['discriminator'])['mapping']);
    for (final v in mapping.values) {
      if (_refName(v as String) == name) found = parent;
    }
  });
  return found;
}

String _genApiPaths(Map<String, dynamic> api) {
  final paths = _asMap(api['paths']);
  final b = StringBuffer()
    ..writeln(_header)
    ..writeln('/// Path constants/builders for the /v1 surface.')
    ..writeln('abstract final class ApiPaths {');
  paths.forEach((path, _) {
    final segs = path.split('/').where((s) => s.isNotEmpty).toList();
    final params = <String>[];
    final nameParts = <String>[];
    for (final s in segs) {
      if (s.startsWith('{')) {
        params.add(_camel(s.substring(1, s.length - 1)));
      } else if (s != 'v1') {
        nameParts.add(s);
      }
    }
    var name = _camel(nameParts.join('_'));
    if (params.isNotEmpty) {
      name = '${name}By${params.map(_pascal).join('And')}';
      final args = params.map((p) => 'String $p').join(', ');
      final interp = segs
          .map(
            (s) => s.startsWith('{')
                ? '\$${_camel(s.substring(1, s.length - 1))}'
                : s,
          )
          .join('/');
      b.writeln("  static String $name($args) => '/$interp';");
    } else {
      b.writeln("  static const String $name = '$path';");
    }
  });
  b.writeln('}');
  return b.toString();
}

// ───────────────────────── main ─────────────────────────

void main() {
  final sse = jsonDecode(
    File('contracts/sse-events.schema.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final errors = jsonDecode(
    File('contracts/error-codes.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final api = jsonDecode(
    jsonEncode(
      loadYaml(File('contracts/rest-api.openapi.yaml').readAsStringSync()),
    ),
  ) as Map<String, dynamic>;

  Directory(_outDir).createSync(recursive: true);
  File('$_outDir/sse_events.dart').writeAsStringSync(_genSse(sse));
  File('$_outDir/error_codes.dart').writeAsStringSync(_genErrorCodes(errors));
  File('$_outDir/rest_models.dart').writeAsStringSync(_genRestModels(api));
  File('$_outDir/api_paths.dart').writeAsStringSync(_genApiPaths(api));
  stdout.writeln('generated 4 files into $_outDir');
}
