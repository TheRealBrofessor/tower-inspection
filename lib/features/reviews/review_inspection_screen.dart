import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../inspections/inspection_bloc.dart';
import '../inspections/inspection_detail_screen.dart';
import '../reports/report_preview_screen.dart';
import 'review_findings.dart';

class ReviewInspectionScreen extends StatefulWidget {
  const ReviewInspectionScreen({super.key, required this.inspectionId});

  final String inspectionId;

  @override
  State<ReviewInspectionScreen> createState() => _ReviewInspectionScreenState();
}

class _ReviewInspectionScreenState extends State<ReviewInspectionScreen> {
  bool _loadStarted = false;
  bool _updatingStatus = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<InspectionBloc>();
    if (bloc.activeInspection?.id != widget.inspectionId && !_loadStarted) {
      _loadStarted = true;
      unawaited(bloc.openInspection(widget.inspectionId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<InspectionBloc>();
    final inspection = bloc.activeInspection?.id == widget.inspectionId
        ? bloc.activeInspection
        : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Review inspection')),
      body: inspection == null
          ? Center(
              child: bloc.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Inspection could not be loaded.'),
            )
          : _buildReview(context, bloc, inspection),
    );
  }

  Widget _buildReview(
    BuildContext context,
    InspectionBloc bloc,
    Inspection inspection,
  ) {
    final findings = buildReviewFindings(bloc.template, inspection);
    final errorCount = findings
        .where((finding) => finding.severity == ReviewFindingSeverity.error)
        .length;
    final warningCount = findings.length - errorCount;
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              children: [
                _ReviewSummary(
                  status: inspection.status,
                  errorCount: errorCount,
                  warningCount: warningCount,
                ),
                const SizedBox(height: 18),
                Text(
                  'FINDINGS',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (findings.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_outline),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('No findings. Ready to review.'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final finding in findings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FindingRow(
                        key: Key('finding-${finding.id}'),
                        finding: finding,
                        onTap: () => _openFinding(bloc, inspection, finding),
                      ),
                    ),
              ],
            ),
          ),
          if (inspection.status == InspectionStatus.readyForReview ||
              inspection.status == InspectionStatus.completed)
            _ReportAction(onPressed: () => _openReport(inspection)),
          _StatusAction(
            inspection: inspection,
            hasErrors: errorCount > 0,
            busy: _updatingStatus,
            onPressed: () => _advanceStatus(bloc, inspection, errorCount),
          ),
        ],
      ),
    );
  }

  Future<void> _openFinding(
    InspectionBloc bloc,
    Inspection inspection,
    ReviewFinding finding,
  ) async {
    final firstItemId = bloc.template.items.isEmpty
        ? null
        : bloc.template.items.first.id;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InspectionDetailScreen(
          inspectionId: inspection.id,
          initialInspection: inspection,
          initialItemId: finding.itemId ?? firstItemId,
        ),
      ),
    );
  }

  Future<void> _advanceStatus(
    InspectionBloc bloc,
    Inspection inspection,
    int errorCount,
  ) async {
    if (_updatingStatus || errorCount > 0) return;
    setState(() => _updatingStatus = true);
    final completed = inspection.status == InspectionStatus.readyForReview;
    final succeeded = completed
        ? await bloc.markCompleted()
        : await bloc.markReadyForReview();
    if (!mounted) return;
    setState(() => _updatingStatus = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          succeeded
              ? completed
                    ? 'Inspection marked completed.'
                    : 'Inspection is ready for review.'
              : 'Inspection status could not be updated.',
        ),
      ),
    );
  }

  Future<void> _openReport(Inspection inspection) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ReportPreviewScreen(inspectionId: inspection.id),
        ),
      );
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.status,
    required this.errorCount,
    required this.warningCount,
  });

  final InspectionStatus status;
  final int errorCount;
  final int warningCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inspection status',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              status.label,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              children: [
                Chip(
                  avatar: const Icon(Icons.error_outline, color: Colors.red),
                  label: Text(
                    '$errorCount ${errorCount == 1 ? 'error' : 'errors'}',
                  ),
                ),
                Chip(
                  avatar: const Icon(
                    Icons.warning_amber_outlined,
                    color: Colors.amber,
                  ),
                  label: Text(
                    '$warningCount ${warningCount == 1 ? 'warning' : 'warnings'}',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow({super.key, required this.finding, required this.onTap});

  final ReviewFinding finding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isError = finding.severity == ReviewFindingSeverity.error;
    final color = isError ? Colors.red.shade700 : Colors.amber.shade800;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: color),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isError ? Icons.error_outline : Icons.warning_amber_outlined,
          color: color,
        ),
        title: Text(finding.title),
        subtitle: Text(finding.message),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _StatusAction extends StatelessWidget {
  const _StatusAction({
    required this.inspection,
    required this.hasErrors,
    required this.busy,
    required this.onPressed,
  });

  final Inspection inspection;
  final bool hasErrors;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isCompleted = inspection.status == InspectionStatus.completed;
    final isReady = inspection.status == InspectionStatus.readyForReview;
    final label = isCompleted
        ? 'COMPLETED'
        : isReady
        ? 'MARK COMPLETED'
        : 'MARK READY FOR REVIEW';
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            key: const Key('mark-ready-button'),
            onPressed: busy || hasErrors || isCompleted ? null : onPressed,
            icon: busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isReady ? Icons.task_alt : Icons.fact_check_outlined),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}

class _ReportAction extends StatelessWidget {
  const _ReportAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            key: const Key('open-report-button'),
            onPressed: onPressed,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('GENERATE REPORT'),
          ),
        ),
      ),
    );
  }
}
