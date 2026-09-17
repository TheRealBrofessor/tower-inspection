import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tower_inspection/core/schema/schema_loader.dart';
import 'package:tower_inspection/data/database.dart';
import 'package:tower_inspection/data/inspection_repository.dart';
import 'package:tower_inspection/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('inspection survives a complete database close and reopen', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'tower-inspection-recovery-',
    );
    final databasePath = path.join(temporaryDirectory.path, 'inspection.db');
    final firstDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: databasePath,
    );

    try {
      final template = await SchemaLoader().load();
      final firstRepository = InspectionRepository(firstDatabase);
      final created = await firstRepository.createInspection(template);
      const siteFields = {
        'siteName': 'Recovery Ridge',
        'asr': '445566',
        'preparedFor': 'Field Operations',
        'address': '100 Offline Way',
        'inspectionDate': '9/16/2026',
      };
      for (final entry in siteFields.entries) {
        await firstRepository.updateSiteField(
          created.id,
          entry.key,
          entry.value,
        );
      }
      await firstRepository.setStatus(created.id, 'A.1', 'Needs Repair');
      await firstRepository.setStatus(created.id, 'A.2', 'Okay');
      await firstRepository.setComments(
        created.id,
        'A.1',
        'Rust at the southwest anchor.',
      );

      final addedPhotos = <PhotoAttachment>[];
      for (var index = 0; index < 3; index++) {
        final photoPath = path.join(temporaryDirectory.path, 'mock-$index.jpg');
        await File(photoPath).writeAsBytes(
          image.encodeJpg(image.Image(width: 4, height: 4), quality: 80),
        );
        addedPhotos.add(
          await firstRepository.addPhoto(
            inspectionId: created.id,
            itemId: 'A.1',
            originalPath: photoPath,
            reportPath: photoPath,
            capturedAt: DateTime.utc(2026, 9, 16, 12, index),
          ),
        );
      }
      final expectedOrder = [
        addedPhotos[2].id,
        addedPhotos[0].id,
        addedPhotos[1].id,
      ];
      await firstRepository.reorderPhotos(created.id, 'A.1', expectedOrder);

      await firstDatabase.close();

      final reopenedDatabase = AppDatabase(
        factory: databaseFactoryFfi,
        databasePath: databasePath,
      );
      final reopenedRepository = InspectionRepository(reopenedDatabase);
      final recovered = await reopenedRepository.getInspection(created.id);
      final database = await reopenedDatabase.database;

      expect(recovered, isNotNull);
      expect(recovered!.siteFields, siteFields);
      expect(recovered.status, InspectionStatus.inProgress);
      expect(recovered.responseFor('A.1')!.status, 'Needs Repair');
      expect(recovered.responseFor('A.2')!.status, 'Okay');
      expect(
        recovered.responseFor('A.1')!.comments,
        'Rust at the southwest anchor.',
      );
      final photos = recovered.responseFor('A.1')!.photos;
      expect(photos.map((photo) => photo.id), expectedOrder);
      expect(photos.map((photo) => photo.orderIndex), [0, 1, 2]);
      expect(
        photos.map((photo) => photo.originalPath),
        expectedOrder.map(
          (id) =>
              addedPhotos.singleWhere((photo) => photo.id == id).originalPath,
        ),
      );
      expect(
        (await database.rawQuery('PRAGMA foreign_keys')).single.values.single,
        1,
      );
      expect(
        (await database.rawQuery('PRAGMA journal_mode')).single.values.single
            .toString()
            .toLowerCase(),
        'wal',
      );
      await reopenedDatabase.close();
    } finally {
      await firstDatabase.close();
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
