import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tower_inspection/data/database.dart';
import 'package:tower_inspection/data/inspection_repository.dart';
import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/reports/report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('writes a timestamped report and records it in the database', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'tower-report-service-',
    );
    final appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    try {
      final template = _template();
      final repository = InspectionRepository(
        appDatabase,
        now: () => DateTime(2026, 9, 16, 10, 30),
      );
      final inspection = await repository.createInspection(template);
      final service = ReportService(
        repository: repository,
        template: template,
        documentsDirectory: () async => temporaryDirectory,
        now: () => DateTime(2026, 9, 16, 10, 30),
      );

      final reportPath = await service.generateReport(inspection.id);
      final reports = await repository.listReports(inspection.id);

      expect(
        reportPath,
        path.join(
          temporaryDirectory.path,
          'reports',
          inspection.id,
          '20260916-103000.pdf',
        ),
      );
      expect(await File(reportPath).length(), greaterThan(0));
      expect(reports, hasLength(1));
      expect(reports.single.filePath, reportPath);
      expect(reports.single.metadata['byteLength'], greaterThan(0));
    } finally {
      await appDatabase.close();
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
  siteInfoFields: [
    SiteInfoField(id: 'siteName', label: 'Site Name'),
    SiteInfoField(id: 'asr', label: 'ASR'),
    SiteInfoField(id: 'preparedFor', label: 'Prepared for'),
    SiteInfoField(id: 'address', label: 'Address'),
    SiteInfoField(id: 'inspectionDate', label: 'Inspection date', type: 'date'),
  ],
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
          id: 'A.4',
          title: 'Ladder',
          instruction: 'Verify ladder',
          fullLabel: 'A.4 Ladder - Verify ladder.',
          statuses: [
            'Okay',
            'Possible Improvement',
            'Needs Repair',
            'Not Applicable',
          ],
          photosEnabled: false,
          photoBlocks: [],
          defaultPhotoSlots: 3,
          commentsEnabled: true,
          prefilledObservation: 'Ladder is integrated into tower.',
        ),
      ],
    ),
  ],
);
