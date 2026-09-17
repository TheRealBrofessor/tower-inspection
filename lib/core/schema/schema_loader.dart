import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/models.dart';

class SchemaLoader {
  SchemaLoader({
    AssetBundle? bundle,
    this.assetPath = 'assets/canonical_form_schema.json',
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  Future<InspectionTemplate> load() async {
    final source = await _bundle.loadString(assetPath);
    return parse(source);
  }

  InspectionTemplate parse(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The inspection schema must be an object.');
    }

    final template = InspectionTemplate.fromJson(decoded);
    _validate(template);
    return template;
  }

  void _validate(InspectionTemplate template) {
    final ids = <String>{};

    void addUnique(String id, String kind) {
      if (id.trim().isEmpty) {
        throw FormatException('$kind id cannot be empty.');
      }
      if (!ids.add(id)) {
        throw FormatException('Duplicate schema id: $id.');
      }
    }

    if (template.defaultStatuses.isEmpty ||
        template.defaultStatuses.any((status) => status.trim().isEmpty)) {
      throw const FormatException('Default statuses cannot be empty.');
    }

    for (final field in template.siteInfoFields) {
      addUnique(field.id, 'Site field');
    }
    for (final section in template.sections) {
      addUnique(section.id, 'Section');
      for (final item in section.items) {
        addUnique(item.id, 'Inspection item');
        if (item.statuses.isEmpty ||
            item.statuses.any((status) => status.trim().isEmpty)) {
          throw FormatException('${item.id} must define nonempty statuses.');
        }
        for (final block in item.photoBlocks) {
          addUnique(block.blockId, 'Photo block');
        }
      }
    }
  }
}
