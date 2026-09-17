import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/reports/pdf_composer.dart';
import 'package:tower_inspection/features/reports/report_layout.dart';

void main() {
  test('composes a paged PDF with report derivative JPEGs', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'tower-pdf-composer-',
    );
    try {
      final jpeg = image.encodeJpg(image.Image(width: 4, height: 3));
      final photos = <String>[];
      for (var index = 0; index < 6; index++) {
        final photoPath = path.join(temporaryDirectory.path, '$index.jpg');
        await File(photoPath).writeAsBytes(jpeg);
        photos.add(photoPath);
      }

      final template = _template();
      final inspection = _inspection(template, photos);
      final layout = ReportLayout.build(
        template: template,
        inspection: inspection,
      );
      final bytes = await PdfComposer().compose(layout);
      final source = latin1.decode(bytes, allowInvalid: true);

      expect(bytes, isNotEmpty);
      expect(latin1.decode(bytes.take(4).toList()), '%PDF');
      expect(RegExp(r'/Type\s*/Page\b').hasMatch(source), isTrue);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });
}

InspectionTemplate _template() => const InspectionTemplate(
  templateVersion: 'test',
  reportTitle: 'Tower Site Inspection Report',
  contractor: ContractorDetails(
    name: 'Elite Tower, LLC',
    address: 'PO Box 30249',
    cityStateZip: 'Savannah, GA 31410',
  ),
  headerConvention: HeaderConvention(
    left: '',
    asrLabel: 'ASR',
    pageLabel: 'Page',
  ),
  siteInfoFields: [],
  defaultStatuses: [
    'Okay',
    'Possible Improvement',
    'Needs Repair',
    'Not Applicable',
  ],
  sections: [
    InspectionSection(
      id: 'A',
      title: 'A.  STRUCTURE CONDITION',
      items: [
        InspectionItem(
          id: 'A.1',
          title: 'Rust',
          instruction: 'Check structure for rust',
          fullLabel: 'A.1 Rust - Check structure for rust.',
          statuses: [
            'Okay',
            'Possible Improvement',
            'Needs Repair',
            'Not Applicable',
          ],
          photosEnabled: true,
          photoBlocks: [],
          defaultPhotoSlots: 3,
          commentsEnabled: true,
          prefilledObservation: '',
        ),
        InspectionItem(
          id: 'A.2',
          title: 'Cross Members',
          instruction: 'Check cross members',
          fullLabel: 'A.2 Cross Members - Check cross members.',
          statuses: [
            'Okay',
            'Possible Improvement',
            'Needs Repair',
            'Not Applicable',
          ],
          photosEnabled: true,
          photoBlocks: [],
          defaultPhotoSlots: 3,
          commentsEnabled: true,
          prefilledObservation: '',
        ),
      ],
    ),
  ],
);

Inspection _inspection(InspectionTemplate template, List<String> photos) {
  final now = DateTime.utc(2026, 9, 16);
  return Inspection(
    id: 'inspection-1',
    templateVersion: template.templateVersion,
    siteFields: const {
      'siteName': 'Smoke Test Site',
      'asr': '123456',
      'preparedFor': 'Operations',
      'address': 'Savannah, GA',
      'inspectionDate': '9/16/2026',
    },
    status: InspectionStatus.readyForReview,
    createdAt: now,
    updatedAt: now,
    responses: [
      for (var itemIndex = 0; itemIndex < template.items.length; itemIndex++)
        InspectionItemResponse(
          inspectionId: 'inspection-1',
          itemId: template.items[itemIndex].id,
          status: itemIndex == 0 ? 'Okay' : 'Needs Repair',
          comments: itemIndex == 0
              ? 'No visible corrosion.'
              : List.filled(100, 'Detailed observation').join(' '),
          photos: [
            for (var photoIndex = 0; photoIndex < 3; photoIndex++)
              PhotoAttachment(
                id: '$itemIndex-$photoIndex',
                inspectionId: 'inspection-1',
                itemId: template.items[itemIndex].id,
                orderIndex: photoIndex,
                originalPath: photos[itemIndex * 3 + photoIndex],
                reportPath: photos[itemIndex * 3 + photoIndex],
                capturedAt: now,
              ),
          ],
        ),
    ],
  );
}
