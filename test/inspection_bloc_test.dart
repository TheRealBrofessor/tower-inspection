import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tower_inspection/data/database.dart';
import 'package:tower_inspection/data/inspection_repository.dart';
import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/inspections/inspection_bloc.dart';

void main() {
  sqfliteFfiInit();

  test('serializes comment saves in call order', () async {
    final repository = _RecordingRepository();
    final template = InspectionTemplate(
      templateVersion: '1.0.0',
      reportTitle: 'Test',
      contractor: const ContractorDetails(
        name: '',
        address: '',
        cityStateZip: '',
      ),
      headerConvention: const HeaderConvention(
        left: '',
        asrLabel: '',
        pageLabel: '',
      ),
      siteInfoFields: const [],
      defaultStatuses: const [],
      sections: const [],
    );
    final bloc = InspectionBloc(template: template, repository: repository)
      ..activeInspection = Inspection(
        id: 'inspection-1',
        templateVersion: '1.0.0',
        siteFields: const {},
        status: InspectionStatus.inProgress,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        responses: const [
          InspectionItemResponse(
            inspectionId: 'inspection-1',
            itemId: 'A.1',
          ),
        ],
      );

    final firstSave = bloc.setComments('A.1', 'first');
    await repository.firstSaveStarted.future;
    final secondSave = bloc.setComments('A.1', 'second');

    expect(repository.savedComments, isEmpty);
    repository.releaseFirstSave.complete();

    expect(await firstSave, isTrue);
    expect(await secondSave, isTrue);
    expect(repository.savedComments, ['first', 'second']);
    expect(bloc.isSaving, isFalse);
  });
}

class _RecordingRepository extends InspectionRepository {
  _RecordingRepository()
    : super(
        AppDatabase(
          factory: databaseFactoryFfi,
          databasePath: ':memory:',
        ),
      );

  final firstSaveStarted = Completer<void>();
  final releaseFirstSave = Completer<void>();
  final savedComments = <String>[];

  @override
  Future<void> setComments(
    String inspectionId,
    String itemId,
    String comments,
  ) async {
    if (comments == 'first') {
      firstSaveStarted.complete();
      await releaseFirstSave.future;
    }
    savedComments.add(comments);
  }
}
