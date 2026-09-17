import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import 'inspection_bloc.dart';
import 'inspection_detail_screen.dart';

class InspectionListScreen extends StatelessWidget {
  const InspectionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<InspectionBloc>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tower inspections'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.offline_bolt_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: bloc.initialize,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  key: const Key('new-inspection-button'),
                  onPressed: bloc.isLoading
                      ? null
                      : () => _createInspection(context, bloc),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('NEW INSPECTION'),
                ),
              ),
              if (bloc.lastError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(onRetry: bloc.initialize),
              ],
              const SizedBox(height: 28),
              _InspectionGroup(
                title: 'DRAFTS',
                inspections: bloc.drafts,
                emptyMessage: 'No draft inspections. Start one above.',
              ),
              const SizedBox(height: 28),
              _InspectionGroup(
                title: 'COMPLETED',
                inspections: bloc.completed,
                emptyMessage: 'Completed inspections will appear here.',
              ),
              if (bloc.isLoading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createInspection(
    BuildContext context,
    InspectionBloc bloc,
  ) async {
    final inspection = await bloc.createInspection();
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => InspectionDetailScreen(
          inspectionId: inspection.id,
          initialInspection: inspection,
        ),
      ),
    );
    unawaited(bloc.initialize());
  }
}

class _InspectionGroup extends StatelessWidget {
  const _InspectionGroup({
    required this.title,
    required this.inspections,
    required this.emptyMessage,
  });

  final String title;
  final List<Inspection> inspections;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        if (inspections.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(emptyMessage),
          )
        else
          ...inspections.map(
            (inspection) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InspectionRow(inspection: inspection),
            ),
          ),
      ],
    );
  }
}

class _InspectionRow extends StatelessWidget {
  const _InspectionRow({required this.inspection});

  final Inspection inspection;

  @override
  Widget build(BuildContext context) {
    final siteName = inspection.siteFields['siteName']?.trim();
    final asr = inspection.siteFields['asr']?.trim();
    final inspectionDate = inspection.siteFields['inspectionDate']?.trim();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => InspectionDetailScreen(inspectionId: inspection.id),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.cell_tower),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      siteName == null || siteName.isEmpty
                          ? 'Unnamed site'
                          : siteName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ASR: ${asr == null || asr.isEmpty ? 'Not entered' : asr}',
                    ),
                    Text(
                      inspectionDate == null || inspectionDate.isEmpty
                          ? DateFormat.yMMMd().format(inspection.createdAt)
                          : inspectionDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  inspection.status == Inspection.completedStatus
                      ? 'Completed'
                      : 'Draft',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            const Expanded(child: Text('Local data could not be loaded.')),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
