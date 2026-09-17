import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tower_inspection/data/database.dart';
import 'package:tower_inspection/data/inspection_repository.dart';
import 'package:tower_inspection/domain/models.dart';
import 'package:tower_inspection/features/inspections/inspection_bloc.dart';
import 'package:tower_inspection/features/inspections/inspection_detail_screen.dart';
import 'package:tower_inspection/features/reviews/review_findings.dart';
import 'package:tower_inspection/features/reviews/review_inspection_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  testWidgets(
    'review findings navigate to items and errors gate ready status',
    (tester) async {
      final template = _template();
      final inspection = _inspection(template);
      final repository = _ReviewRepository(inspection);
      final bloc = InspectionBloc(template: template, repository: repository);
      await bloc.openInspection(inspection.id);

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: bloc,
          child: const MaterialApp(
            home: ReviewInspectionScreen(inspectionId: 'review-test'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 errors'), findsOneWidget);
      expect(find.text('1 warning'), findsOneWidget);
      var readyButton = tester.widget<FilledButton>(
        find.byKey(const Key('mark-ready-button')),
      );
      expect(readyButton.onPressed, isNull);

      final firstFinding = find.byKey(const Key('finding-status-item-1'));
      await tester.ensureVisible(firstFinding);
      await tester.tap(firstFinding);
      await tester.pumpAndSettle();
      expect(find.byType(InspectionDetailScreen), findsOneWidget);
      expect(find.text('1. First item.'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await bloc.setItemStatus('item-1', 'Okay');
      await bloc.setItemStatus('item-2', 'Okay');
      await tester.pumpAndSettle();

      expect(find.text('0 errors'), findsOneWidget);
      expect(find.text('1 warning'), findsOneWidget);
      readyButton = tester.widget<FilledButton>(
        find.byKey(const Key('mark-ready-button')),
      );
      expect(readyButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('mark-ready-button')));
      await tester.pumpAndSettle();
      expect(find.text('Ready for Review'), findsOneWidget);
      expect(find.text('MARK COMPLETED'), findsOneWidget);
    },
  );

  test('required fields exclude address and repair comments are warned', () {
    final template = _template();
    final base = _inspection(template);
    final inspection = base.copyWith(
      siteFields: const {
        'siteName': '',
        'asr': '  ',
        'preparedFor': 'Operations',
        'inspectionDate': '9/16/2026',
      },
      responses: [
        base.responseFor('item-1')!.copyWith(status: 'Needs Repair'),
        base
            .responseFor('item-2')!
            .copyWith(
              status: 'Okay',
              photos: [
                PhotoAttachment(
                  id: 'photo-1',
                  inspectionId: base.id,
                  itemId: 'item-2',
                  orderIndex: 0,
                  originalPath: '/photo.jpg',
                  reportPath: '/photo-report.jpg',
                  capturedAt: DateTime.utc(2026, 9, 16),
                ),
              ],
            ),
      ],
    );

    final findings = buildReviewFindings(template, inspection);

    expect(findings.map((finding) => finding.id).toSet(), {
      'site-siteName',
      'site-asr',
      'comments-item-1',
    });
    expect(findings.any((finding) => finding.id == 'site-address'), isFalse);
  });
}

InspectionTemplate _template() => const InspectionTemplate(
  templateVersion: 'test',
  reportTitle: 'Test report',
  contractor: ContractorDetails(name: 'Test', address: '', cityStateZip: ''),
  headerConvention: HeaderConvention(left: '', asrLabel: '', pageLabel: ''),
  siteInfoFields: [
    SiteInfoField(id: 'siteName', label: 'Site Name'),
    SiteInfoField(id: 'asr', label: 'ASR'),
    SiteInfoField(id: 'preparedFor', label: 'Prepared for'),
    SiteInfoField(id: 'inspectionDate', label: 'Date'),
  ],
  defaultStatuses: ['Okay', 'Possible Improvement', 'Needs Repair'],
  sections: [
    InspectionSection(
      id: '1',
      title: 'Section',
      items: [
        InspectionItem(
          id: 'item-1',
          title: 'First',
          instruction: 'First',
          fullLabel: '1. First item.',
          statuses: ['Okay', 'Possible Improvement', 'Needs Repair'],
          photosEnabled: false,
          photoBlocks: [],
          defaultPhotoSlots: 0,
          commentsEnabled: true,
          prefilledObservation: '',
        ),
        InspectionItem(
          id: 'item-2',
          title: 'Second',
          instruction: 'Second',
          fullLabel: '2. Second item.',
          statuses: ['Okay', 'Possible Improvement', 'Needs Repair'],
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

Inspection _inspection(InspectionTemplate template) {
  final now = DateTime.utc(2026, 9, 16);
  return Inspection(
    id: 'review-test',
    templateVersion: template.templateVersion,
    siteFields: const {
      'siteName': 'Review Site',
      'asr': '1234',
      'preparedFor': 'Operations',
      'inspectionDate': '9/16/2026',
    },
    status: InspectionStatus.draft,
    createdAt: now,
    updatedAt: now,
    responses: [
      for (final item in template.items)
        InspectionItemResponse(inspectionId: 'review-test', itemId: item.id),
    ],
  );
}

class _ReviewRepository extends InspectionRepository {
  _ReviewRepository(this.inspection)
    : super(AppDatabase(factory: databaseFactoryFfi));

  final Inspection inspection;

  @override
  Future<Inspection?> getInspection(String id) async => inspection;

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

  @override
  Future<void> updateSiteField(
    String inspectionId,
    String fieldId,
    String value,
  ) async {}

  @override
  Future<void> updateInspectionStatus(
    String inspectionId,
    InspectionStatus status,
  ) async {}
}
