import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tower_inspection/core/schema/schema_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SchemaLoader', () {
    test('loads the canonical five-section, 18-item template', () async {
      final template = await SchemaLoader().load();

      expect(template.templateVersion, '1.0.0');
      expect(template.sections.map((section) => section.id), [
        'A',
        'B',
        'C',
        'D',
        'E',
      ]);
      expect(template.items, hasLength(18));
      expect(template.defaultStatuses, [
        'Okay',
        'Possible Improvement',
        'Needs Repair',
        'Not Applicable',
      ]);

      final ladder = template.itemById('A.4')!;
      expect(ladder.photosEnabled, isFalse);
      expect(ladder.photoBlocks, isEmpty);
      expect(
        ladder.prefilledObservation,
        'Ladder is integrated into Cross member design of tower and welded.',
      );
    });

    test('rejects duplicate ids', () async {
      final source = await rootBundle.loadString(
        'assets/canonical_form_schema.json',
      );
      final json = jsonDecode(source) as Map<String, dynamic>;
      final sections = json['sections']! as List<dynamic>;
      final firstItems =
          (sections.first as Map<String, dynamic>)['items']! as List<dynamic>;
      (firstItems[1] as Map<String, dynamic>)['id'] = 'A.1';

      expect(
        () => SchemaLoader().parse(jsonEncode(json)),
        throwsFormatException,
      );
    });

    test('rejects an empty item status list', () async {
      final source = await rootBundle.loadString(
        'assets/canonical_form_schema.json',
      );
      final json = jsonDecode(source) as Map<String, dynamic>;
      final sections = json['sections']! as List<dynamic>;
      final firstItems =
          (sections.first as Map<String, dynamic>)['items']! as List<dynamic>;
      (firstItems.first as Map<String, dynamic>)['statuses'] = <String>[];

      expect(
        () => SchemaLoader().parse(jsonEncode(json)),
        throwsFormatException,
      );
    });
  });
}
