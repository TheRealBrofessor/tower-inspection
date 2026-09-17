// Fidelity harness: builds a realistic sample inspection and writes the PDF.
// Run: dart run tool/fidelity_sample.dart <output.pdf>
// Pure Dart — report engine is UI-independent.

import 'dart:convert';
import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/reports/pdf_composer.dart';
import 'package:tower_inspection/features/reports/report_layout.dart';

Future<void> main(List<String> args) async {
  final outPath = args.isNotEmpty ? args[0] : 'sample_report.pdf';

  final schemaSource = File('assets/canonical_form_schema.json').readAsStringSync();
  final decoded = jsonDecode(schemaSource) as Map<String, dynamic>;
  final template = InspectionTemplate.fromJson(decoded);

  final inspectionId = 'sample-fidelity-001';
  final photoDir = Directory('build/fidelity_photos');
  if (photoDir.existsSync()) photoDir.deleteSync(recursive: true);
  photoDir.createSync(recursive: true);

  PhotoAttachment mkPhoto(String itemId, int index) {
    final photo = img.Image(width: 160, height: 160);
    img.fill(photo, color: img.ColorRgb8(40 + index * 30, 90, 150));
    final bytes = img.encodeJpg(photo, quality: 80);
    final p = '${photoDir.path}/${itemId.replaceAll('.', '_')}_$index.jpg';
    File(p).writeAsBytesSync(bytes);
    return PhotoAttachment(
      id: const Uuid().v4(),
      inspectionId: inspectionId,
      itemId: itemId,
      orderIndex: index,
      originalPath: p,
      reportPath: p,
      capturedAt: DateTime.now(),
    );
  }

  final responses = <InspectionItemResponse>[];
  var i = 0;
  for (final item in template.items) {
    i++;
    final status = switch (i % 4) {
      0 => 'Okay',
      1 => 'Needs Repair',
      2 => 'Possible Improvement',
      _ => 'Not Applicable',
    };
    final longComment = i == 3
        ? 'Long observation: ' * 40 +
              'Rust bloom near base welds; recommend wire-brush, prime, and repaint within 90 days. Guyed structure; verify anchor torque at next visit.'
        : (status == 'Okay' ? '' : 'Action recommended for $status on ${item.id}.');
    final photosForItem = <PhotoAttachment>[];
    if (item.photosEnabled) {
      final n = switch (i % 5) {
        0 => 1,
        1 => 3,
        2 => 4,
        3 => 7,
        _ => 0,
      };
      for (var p = 0; p < n; p++) {
        photosForItem.add(mkPhoto(item.id, p));
      }
    }
    responses.add(
      InspectionItemResponse(
        inspectionId: inspectionId,
        itemId: item.id,
        status: status,
        comments: longComment,
        photos: photosForItem,
      ),
    );
  }

  final inspection = Inspection(
    id: inspectionId,
    templateVersion: template.templateVersion,
    siteFields: {
      'siteName': 'Harmony Remote',
      'asr': '1322046',
      'preparedFor': 'Motorola',
      'address': 'Savannah, GA 31419',
      'inspectionDate': '09/16/2026',
    },
    status: InspectionStatus.completed,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    responses: responses,
  );

  final layout = buildReportLayout(template, inspection);
  final bytes = await composeReportPdf(layout);

  File(outPath)
    ..createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  print('WROTE $outPath bytes=${bytes.length}');
}
