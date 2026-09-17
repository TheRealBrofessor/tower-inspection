import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tower_inspection/core/schema/schema_loader.dart';
import 'package:tower_inspection/data/database.dart';
import 'package:tower_inspection/data/inspection_repository.dart';
import 'package:tower_inspection/domain/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late AppDatabase appDatabase;
  late InspectionRepository repository;

  setUp(() {
    appDatabase = AppDatabase(
      factory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
    );
    repository = InspectionRepository(
      appDatabase,
      now: () => DateTime(2026, 9, 16, 10, 30),
    );
  });

  tearDown(() => appDatabase.close());

  test('migration enables constraints and records schema version', () async {
    final database = await appDatabase.database;

    final versions = await database.query('schema_version');
    final foreignKeys = await database.rawQuery('PRAGMA foreign_keys');
    final reportTable = await database.query(
      'sqlite_master',
      columns: ['name'],
      where: 'type = ? AND name = ?',
      whereArgs: ['table', 'reports'],
    );

    expect(versions.single['version'], AppDatabase.currentVersion);
    expect(foreignKeys.single.values.single, 1);
    expect(reportTable, hasLength(1));
  });

  test(
    'repository persists a full inspection tree and autosave fields',
    () async {
      final template = await SchemaLoader().load();
      final created = await repository.createInspection(template);

      expect(created.status, Inspection.draftStatus);
      expect(created.responses, hasLength(18));
      expect(created.siteFields['inspectionDate'], '9/16/2026');
      expect(
        created.responseFor('A.4')!.comments,
        'Ladder is integrated into Cross member design of tower and welded.',
      );

      await repository.updateSiteField(
        created.id,
        'siteName',
        'Harmony Remote',
      );
      await repository.setStatus(created.id, 'A.1', 'Needs Repair');
      await repository.setComments(created.id, 'A.1', 'Surface rust at base.');
      final firstPhoto = await repository.addPhoto(
        inspectionId: created.id,
        itemId: 'A.1',
        originalPath: '/photos/one.jpg',
      );
      final secondPhoto = await repository.addPhoto(
        inspectionId: created.id,
        itemId: 'A.1',
        originalPath: '/photos/two.jpg',
      );
      await repository.reorderPhotos(created.id, 'A.1', [
        secondPhoto.id,
        firstPhoto.id,
      ]);

      var loaded = (await repository.getInspection(created.id))!;
      expect(loaded.siteFields['siteName'], 'Harmony Remote');
      expect(loaded.responseFor('A.1')!.status, 'Needs Repair');
      expect(loaded.responseFor('A.1')!.comments, 'Surface rust at base.');
      expect(loaded.responseFor('A.1')!.photos.map((photo) => photo.id), [
        secondPhoto.id,
        firstPhoto.id,
      ]);

      await repository.deletePhoto(secondPhoto.id);
      loaded = (await repository.getInspection(created.id))!;
      expect(loaded.responseFor('A.1')!.photos.single.orderIndex, 0);
      expect(
        await repository.listInspectionsByStatus(Inspection.draftStatus),
        hasLength(1),
      );
      expect(
        await repository.listInspectionsByStatus(Inspection.completedStatus),
        isEmpty,
      );
    },
  );

  test('foreign keys reject photos without an item response', () async {
    final database = await appDatabase.database;

    expect(
      () => database.insert('photo_attachments', {
        'id': 'orphan',
        'inspection_id': 'missing-inspection',
        'item_id': 'A.1',
        'order_index': 0,
        'original_path': '/tmp/orphan.jpg',
        'report_path': '/tmp/orphan.jpg',
        'captured_at': DateTime(2026).toIso8601String(),
        'metadata_json': '{}',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
