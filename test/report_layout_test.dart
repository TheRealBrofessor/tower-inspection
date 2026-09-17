import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/reports/report_layout.dart';

void main() {
  late InspectionTemplate template;

  setUpAll(() async {
    final source = await File('assets/canonical_form_schema.json')
        .readAsString();
    template = InspectionTemplate.fromJson(
      jsonDecode(source) as Map<String, dynamic>,
    );
  });

  test('item order follows the canonical schema', () {
    final layout = ReportLayout.build(
      template: template,
      inspection: _inspection(template),
    );

    expect(
      layout.items.map((item) => item.itemId),
      template.items.map((item) => item.id),
    );
  });

  test('status row selects only the saved status', () {
    final layout = ReportLayout.build(
      template: template,
      inspection: _inspection(template, selectedStatus: 'Needs Repair'),
    );
    final status = layout.items.first.status;

    expect(status.selectedStatus, 'Needs Repair');
    expect(
      status.cells.where((cell) => cell.selected).map((cell) => cell.label),
      ['Needs Repair'],
    );
    expect(status.cells, hasLength(4));
  });

  for (final testCase in const [
    (photos: 0, blocks: 1, lastEmpty: 3),
    (photos: 1, blocks: 1, lastEmpty: 2),
    (photos: 3, blocks: 1, lastEmpty: 0),
    (photos: 4, blocks: 2, lastEmpty: 2),
    (photos: 6, blocks: 2, lastEmpty: 0),
    (photos: 7, blocks: 3, lastEmpty: 2),
    (photos: 9, blocks: 3, lastEmpty: 0),
    (photos: 10, blocks: 4, lastEmpty: 2),
  ]) {
    test('${testCase.photos} photos create ${testCase.blocks} blocks with '
        '${testCase.lastEmpty} final empty slots', () {
      final layout = ReportLayout.build(
        template: template,
        inspection: _inspection(template, a1PhotoCount: testCase.photos),
      );
      final blocks = layout.items.first.photoBlocks;

      expect(blocks, hasLength(testCase.blocks));
      expect(blocks.last.emptySlotCount, testCase.lastEmpty);
      expect(blocks.every((block) => block.slots.length == 3), isTrue);
      expect(blocks.first.label, 'A.1.1 Rust - Photographs');
      if (blocks.length > 1) {
        expect(blocks[1].label, 'A.1.2 Rust – Photographs (Continued)');
      }
    });
  }

  test('A.4 renders its prefilled observation without photo blocks', () {
    final layout = ReportLayout.build(
      template: template,
      inspection: _inspection(template),
    );
    final ladder = layout.items.singleWhere((item) => item.itemId == 'A.4');

    expect(ladder.photoBlocks, isEmpty);
    expect(ladder.hasObservationBlock, isTrue);
    expect(
      ladder.observation!.comments,
      'Ladder is integrated into Cross member design of tower and welded.',
    );
  });

  test('long observations retain text and declare bounded clipping', () {
    final comments = List.filled(101, 'note').join(' ');
    expect(comments.length, greaterThanOrEqualTo(500));
    final layout = ReportLayout.build(
      template: template,
      inspection: _inspection(template, a1Comments: comments),
    );
    final observation = layout.items.first.observation!;

    expect(observation.comments, comments);
    expect(observation.maxLines, greaterThan(0));
    expect(observation.overflow, ReportTextOverflow.clip);
  });
}

Inspection _inspection(
  InspectionTemplate template, {
  int a1PhotoCount = 0,
  String selectedStatus = 'Okay',
  String a1Comments = '',
}) {
  final now = DateTime.utc(2026, 9, 16);
  return Inspection(
    id: 'inspection-1',
    templateVersion: template.templateVersion,
    siteFields: const {
      'siteName': 'Test Site',
      'asr': '123456',
      'preparedFor': 'Operations',
      'address': 'Savannah, GA',
      'inspectionDate': '9/16/2026',
    },
    status: InspectionStatus.readyForReview,
    createdAt: now,
    updatedAt: now,
    responses: [
      for (final item in template.items)
        InspectionItemResponse(
          inspectionId: 'inspection-1',
          itemId: item.id,
          status: selectedStatus,
          comments: item.id == 'A.1' ? a1Comments : item.prefilledObservation,
          photos: item.id == 'A.1'
              ? [
                  for (var index = 0; index < a1PhotoCount; index++)
                    PhotoAttachment(
                      id: 'photo-$index',
                      inspectionId: 'inspection-1',
                      itemId: item.id,
                      orderIndex: index,
                      originalPath: '/tmp/original-$index.jpg',
                      reportPath: '/tmp/report-$index.jpg',
                      capturedAt: now,
                    ),
                ]
              : const [],
        ),
    ],
  );
}
