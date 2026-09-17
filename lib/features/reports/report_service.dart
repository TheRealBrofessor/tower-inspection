import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/inspection_repository.dart';
import '../../domain/models.dart';
import 'pdf_composer.dart';
import 'report_layout.dart';

class ReportService {
  ReportService({
    required this.repository,
    required this.template,
    PdfComposer? composer,
    Future<Directory> Function()? documentsDirectory,
    DateTime Function()? now,
    Uuid? uuid,
  }) : _composer = composer ?? PdfComposer(),
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory,
       _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final InspectionRepository repository;
  final InspectionTemplate template;
  final PdfComposer _composer;
  final Future<Directory> Function() _documentsDirectory;
  final DateTime Function() _now;
  final Uuid _uuid;

  Future<String> generateReport(String inspectionId) async {
    final inspection = await repository.getInspection(inspectionId);
    if (inspection == null) {
      throw StateError('Inspection $inspectionId was not found.');
    }

    final layout = ReportLayout.build(
      template: template,
      inspection: inspection,
    );
    final bytes = await _composer.compose(layout);
    final createdAt = _now();
    final documents = await _documentsDirectory();
    final reportDirectory = Directory(
      path.join(documents.path, 'reports', inspectionId),
    );
    await reportDirectory.create(recursive: true);
    final file = File(
      path.join(
        reportDirectory.path,
        '${DateFormat('yyyyMMdd-HHmmss').format(createdAt)}.pdf',
      ),
    );
    await file.writeAsBytes(bytes, flush: true);

    final report = Report(
      id: _uuid.v4(),
      inspectionId: inspectionId,
      filePath: file.path,
      createdAt: createdAt.toUtc(),
      observations: [
        for (final item in layout.items)
          if (item.observation case final observation?)
            Observation(itemId: item.itemId, text: observation.comments),
      ],
      metadata: {
        'templateVersion': inspection.templateVersion,
        'logicalPageCount': layout.pages.length,
        'byteLength': bytes.length,
      },
    );
    await repository.saveReport(report);
    return file.path;
  }

  Future<String> generate(String inspectionId) => generateReport(inspectionId);
}
