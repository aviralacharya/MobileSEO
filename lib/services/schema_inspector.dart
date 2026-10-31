import 'dart:convert';

import 'package:html/dom.dart' as dom;

class JsonLdScriptReport {
  const JsonLdScriptReport({
    required this.index,
    required this.rawJson,
    required this.isValid,
    required this.formattedJson,
    required this.schemaTypes,
    this.error,
  });

  final int index;
  final String rawJson;
  final bool isValid;
  final String? formattedJson;
  final List<String> schemaTypes;
  final String? error;
}

class SchemaInspection {
  const SchemaInspection({required this.scripts, required this.schemaTypes});

  final List<JsonLdScriptReport> scripts;
  final List<String> schemaTypes;
}

SchemaInspection inspectSchema(dom.Document document) {
  final types = <String>{};
  final scripts = <JsonLdScriptReport>[];
  final elements = document.querySelectorAll(
    'script[type="application/ld+json"]',
  );

  for (var i = 0; i < elements.length; i++) {
    final raw = elements[i].text.trim();
    try {
      final decoded = jsonDecode(raw);
      final scriptTypes = <String>{};
      _collectSchemaTypes(decoded, scriptTypes);
      types.addAll(scriptTypes);
      scripts.add(
        JsonLdScriptReport(
          index: i + 1,
          rawJson: raw,
          isValid: true,
          formattedJson: const JsonEncoder.withIndent('  ').convert(decoded),
          schemaTypes: List.unmodifiable(scriptTypes.toList()..sort()),
        ),
      );
    } on FormatException catch (error) {
      scripts.add(
        JsonLdScriptReport(
          index: i + 1,
          rawJson: raw,
          isValid: false,
          formattedJson: null,
          schemaTypes: const [],
          error: error.message,
        ),
      );
    }
  }

  if (types.isEmpty && document.querySelector('[itemscope]') != null) {
    types.addAll(
      document
          .querySelectorAll('[itemscope][itemtype]')
          .map((element) => element.attributes['itemtype'] ?? '')
          .where((value) => value.isNotEmpty)
          .map((value) => value.split('/').last)
          .where((value) => value.isNotEmpty),
    );
  }

  final sorted = types.toList()..sort();
  return SchemaInspection(
    scripts: List.unmodifiable(scripts),
    schemaTypes: List.unmodifiable(sorted),
  );
}

void _collectSchemaTypes(Object? node, Set<String> types) {
  if (node is List) {
    for (final value in node) {
      _collectSchemaTypes(value, types);
    }
  } else if (node is Map) {
    final type = node['@type'];
    if (type is String && type.trim().isNotEmpty) {
      types.add(type.trim());
    } else if (type is List) {
      types.addAll(type.whereType<String>().where((value) => value.isNotEmpty));
    }
    for (final value in node.values) {
      if (value is Map || value is List) _collectSchemaTypes(value, types);
    }
  }
}
