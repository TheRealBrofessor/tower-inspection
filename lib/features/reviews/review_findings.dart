import '../../domain/models.dart';

enum ReviewFindingSeverity { error, warning }

class ReviewFinding {
  const ReviewFinding({
    required this.id,
    required this.severity,
    required this.title,
    required this.message,
    this.itemId,
  });

  final String id;
  final ReviewFindingSeverity severity;
  final String title;
  final String message;
  final String? itemId;
}

List<ReviewFinding> buildReviewFindings(
  InspectionTemplate template,
  Inspection inspection,
) {
  const requiredSiteFields = {
    'siteName': 'Site Name',
    'asr': 'ASR',
    'preparedFor': 'Prepared for',
    'inspectionDate': 'Date of Inspection',
  };
  final findings = <ReviewFinding>[];

  for (final entry in requiredSiteFields.entries) {
    if ((inspection.siteFields[entry.key] ?? '').trim().isEmpty) {
      findings.add(
        ReviewFinding(
          id: 'site-${entry.key}',
          severity: ReviewFindingSeverity.error,
          title: '${entry.value} is required',
          message: 'Enter this required site field before review.',
        ),
      );
    }
  }

  for (final item in template.items) {
    final response = inspection.responseFor(item.id);
    if (response?.status == null || response!.status!.trim().isEmpty) {
      findings.add(
        ReviewFinding(
          id: 'status-${item.id}',
          severity: ReviewFindingSeverity.error,
          title: '${item.id}: Select a status',
          message: item.title,
          itemId: item.id,
        ),
      );
    }
    if (item.photosEnabled && (response?.photos.isEmpty ?? true)) {
      findings.add(
        ReviewFinding(
          id: 'photos-${item.id}',
          severity: ReviewFindingSeverity.warning,
          title: '${item.id}: No photos',
          message: 'This photo-enabled item has no photos.',
          itemId: item.id,
        ),
      );
    }
    final needsExplanation =
        response?.status == 'Needs Repair' ||
        response?.status == 'Possible Improvement';
    if (needsExplanation && (response?.comments.trim().isEmpty ?? true)) {
      findings.add(
        ReviewFinding(
          id: 'comments-${item.id}',
          severity: ReviewFindingSeverity.warning,
          title: '${item.id}: Explanation recommended',
          message: '${response!.status} has no supporting comments.',
          itemId: item.id,
        ),
      );
    }
  }

  return findings;
}
