import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../inspections/inspection_bloc.dart';
import 'report_service.dart';
import 'share_plus_adapter.dart';

class ReportPreviewScreen extends StatefulWidget {
  const ReportPreviewScreen({
    super.key,
    required this.inspectionId,
    this.reportService,
  });

  final String inspectionId;
  final ReportService? reportService;

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  ReportService? _reportService;
  String? _reportPath;
  int? _reportSize;
  Object? _error;
  bool _generating = false;
  bool _sharing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportService ??= widget.reportService ?? _serviceFromContext();
  }

  ReportService _serviceFromContext() {
    final bloc = context.read<InspectionBloc>();
    return ReportService(repository: bloc.repository, template: bloc.template);
  }

  @override
  Widget build(BuildContext context) {
    final reportPath = _reportPath;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection report'),
        actions: [
          IconButton(
            key: const Key('share-report-button'),
            tooltip: 'Share report',
            onPressed: reportPath == null || _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_generating) const LinearProgressIndicator(minHeight: 3),
            if (_error != null)
              Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Report generation failed: $_error'),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: reportPath == null
                  ? _EmptyPreview(
                      generating: _generating,
                      onGenerate: _generate,
                    )
                  : PdfPreview(
                      key: ValueKey(reportPath),
                      build: (_) => File(reportPath).readAsBytes(),
                      initialPageFormat: PdfPageFormat.letter,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      dynamicLayout: false,
                      allowSharing: false,
                      pdfFileName: path.basename(reportPath),
                    ),
            ),
            if (reportPath != null)
              _ReportFileBar(
                reportPath: reportPath,
                reportSize: _reportSize ?? 0,
                generating: _generating,
                sharing: _sharing,
                onGenerate: _generate,
                onShare: _share,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _generate() async {
    if (_generating) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final reportPath = await _reportService!.generateReport(
        widget.inspectionId,
      );
      final size = await File(reportPath).length();
      if (!mounted) return;
      setState(() {
        _reportPath = reportPath;
        _reportSize = size;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _share() async {
    final reportPath = _reportPath;
    if (reportPath == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(reportPath)]));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report could not be shared: $error')),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview({required this.generating, required this.onGenerate});

  final bool generating;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Generate a source-faithful PDF from the saved inspection.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const Key('generate-report-button'),
                onPressed: generating ? null : onGenerate,
                icon: generating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(generating ? 'GENERATING…' : 'GENERATE REPORT'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportFileBar extends StatelessWidget {
  const _ReportFileBar({
    required this.reportPath,
    required this.reportSize,
    required this.generating,
    required this.sharing,
    required this.onGenerate,
    required this.onShare,
  });

  final String reportPath;
  final int reportSize;
  final bool generating;
  final bool sharing;
  final VoidCallback onGenerate;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            const Icon(Icons.description_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reportPath,
                    key: const Key('generated-report-path'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatBytes(reportSize),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Regenerate report',
              onPressed: generating ? null : onGenerate,
              icon: const Icon(Icons.refresh),
            ),
            FilledButton.icon(
              onPressed: sharing ? null : onShare,
              icon: const Icon(Icons.ios_share),
              label: const Text('SHARE'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }
}
