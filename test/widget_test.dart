import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tower_inspection/core/schema/schema_loader.dart';
import 'package:tower_inspection/data/database.dart';
import 'package:tower_inspection/data/inspection_repository.dart';
import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/inspections/inspection_bloc.dart';
import 'package:tower_inspection/features/inspections/inspection_detail_screen.dart';
import 'package:tower_inspection/features/inspections/inspection_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets('creates an inspection and navigates the canonical item order', (
    tester,
  ) async {
    final template = await SchemaLoader().load();
    final repository = _FakeInspectionRepository();
    final bloc = InspectionBloc(template: template, repository: repository);
    await bloc.initialize();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: bloc,
        child: const MaterialApp(home: InspectionListScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Tower inspections'), findsOneWidget);
    expect(find.text('DRAFTS'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.text('No draft inspections. Start one above.'), findsOneWidget);

    final inspection = await bloc.createInspection();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: bloc,
        child: MaterialApp(
          home: InspectionDetailScreen(
            inspectionId: inspection.id,
            initialInspection: inspection,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A.1 Rust - Check structure for rust.'), findsOneWidget);
    expect(find.text('☐ Okay'), findsOneWidget);
    expect(find.byKey(const Key('add-photo-button')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('status-Okay')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('status-Okay')));
    await tester.pump();
    expect(find.text('☑ Okay'), findsOneWidget);

    for (var index = 0; index < 3; index++) {
      await tester.tap(find.text('NEXT'));
      await tester.pump();
    }

    expect(
      find.text('A.4 Ladder - Verify that ladder system is secured to tower.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('add-photo-button')), findsNothing);
    expect(
      find.text(
        'Ladder is integrated into Cross member design of tower and welded.',
      ),
      findsOneWidget,
    );
  });
}

class _FakeInspectionRepository extends InspectionRepository {
  _FakeInspectionRepository()
    : super(AppDatabase(factory: databaseFactoryFfi));

  Inspection? _inspection;

  @override
  Future<List<Inspection>> listInspectionsByStatus(String status) async =>
      _inspection?.status == status ? [_inspection!] : [];

  @override
  Future<Inspection> createInspection(InspectionTemplate template) async {
    final now = DateTime(2026, 9, 16);
    _inspection = Inspection(
      id: 'widget-test-inspection',
      templateVersion: template.templateVersion,
      siteFields: {
        'siteName': '',
        'asr': '',
        'preparedFor': '',
        'inspectionDate': '9/16/2026',
      },
      status: Inspection.draftStatus,
      createdAt: now,
      updatedAt: now,
      responses: [
        for (final item in template.items)
          InspectionItemResponse(
            inspectionId: 'widget-test-inspection',
            itemId: item.id,
            comments: item.prefilledObservation,
          ),
      ],
    );
    return _inspection!;
  }

  @override
  Future<Inspection?> getInspection(String id) async => _inspection;

  @override
  Future<void> updateSiteField(
    String inspectionId,
    String fieldId,
    String value,
  ) async {}

  @override
  Future<void> setStatus(
    String inspectionId,
    String itemId,
    String status,
  ) async {}

  @override
  Future<void> setComments(
    String inspectionId,
    String itemId,
    String comments,
  ) async {}
}
