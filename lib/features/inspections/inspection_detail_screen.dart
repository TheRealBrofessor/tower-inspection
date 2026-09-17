import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/photo_storage.dart';
import '../../domain/models.dart';
import 'inspection_bloc.dart';

class InspectionDetailScreen extends StatefulWidget {
  const InspectionDetailScreen({
    super.key,
    required this.inspectionId,
    this.initialInspection,
    this.initialItemId,
  });

  final String inspectionId;
  final Inspection? initialInspection;
  final String? initialItemId;

  @override
  State<InspectionDetailScreen> createState() => _InspectionDetailScreenState();
}

class _InspectionDetailScreenState extends State<InspectionDetailScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  final PhotoStorage _photoStorage = PhotoStorage();
  final TextEditingController _commentsController = TextEditingController();
  final Map<String, TextEditingController> _siteControllers = {};
  Timer? _commentsTimer;
  InspectionBloc? _bloc;
  String? _boundInspectionId;
  String _lastPersistedComments = '';
  int _currentItemIndex = 0;
  bool _loadStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bloc = context.read<InspectionBloc>();
    _bloc = bloc;
    final active = bloc.activeInspection;
    if (active?.id == widget.inspectionId) {
      _bindInspection(active!);
    } else if (!_loadStarted) {
      _loadStarted = true;
      unawaited(
        bloc.openInspection(widget.inspectionId).then((inspection) {
          if (!mounted || inspection == null) return;
          setState(() => _bindInspection(inspection));
        }),
      );
    }
  }

  @override
  void dispose() {
    _commentsTimer?.cancel();
    if (_commentsController.text != _lastPersistedComments) {
      final item = _currentItem;
      if (item != null) {
        unawaited(_bloc?.setComments(item.id, _commentsController.text));
      }
    }
    _commentsController.dispose();
    for (final controller in _siteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  InspectionItem? get _currentItem {
    final items = _bloc?.template.items ?? const <InspectionItem>[];
    if (_currentItemIndex < 0 || _currentItemIndex >= items.length) return null;
    return items[_currentItemIndex];
  }

  void _bindInspection(Inspection inspection) {
    if (_boundInspectionId == inspection.id) return;
    _boundInspectionId = inspection.id;
    for (final controller in _siteControllers.values) {
      controller.dispose();
    }
    _siteControllers
      ..clear()
      ..addAll({
        for (final field in _bloc!.template.siteInfoFields)
          field.id: TextEditingController(
            text: inspection.siteFields[field.id] ?? '',
          ),
      });
    final requestedIndex = _bloc!.template.items.indexWhere(
      (item) => item.id == widget.initialItemId,
    );
    _currentItemIndex = requestedIndex < 0 ? 0 : requestedIndex;
    final comments = inspection.responseFor(_currentItem!.id)?.comments ?? '';
    _commentsController.text = comments;
    _lastPersistedComments = comments;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<InspectionBloc>();
    final active = bloc.activeInspection;
    final inspection = active?.id == widget.inspectionId
        ? active
        : widget.initialInspection;
    if (inspection != null) _bindInspection(inspection);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          inspection?.siteFields['siteName']?.trim().isNotEmpty == true
              ? inspection!.siteFields['siteName']!
              : 'Inspection',
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: bloc.template.items.isEmpty
                ? 0
                : (_currentItemIndex + 1) / bloc.template.items.length,
            minHeight: 3,
          ),
        ),
      ),
      body: inspection == null
          ? _LoadingOrError(
              isLoading: bloc.isLoading,
              retry: () => bloc.openInspection(widget.inspectionId),
            )
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 920),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _SiteFields(
                              fields: bloc.template.siteInfoFields,
                              controllers: _siteControllers,
                              onChanged: (fieldId, value) => unawaited(
                                bloc.updateSiteField(fieldId, value),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _SectionNavigation(
                              sections: bloc.template.sections,
                              inspection: inspection,
                              currentItemId: _currentItem!.id,
                              onSelect: (item) => _goToItem(item.id),
                            ),
                            const SizedBox(height: 18),
                            _buildItemCard(bloc, inspection),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                _BottomNavigation(
                  current: _currentItemIndex + 1,
                  total: bloc.template.items.length,
                  onPrevious: _currentItemIndex == 0
                      ? null
                      : () => _goToIndex(_currentItemIndex - 1),
                  onNext: _currentItemIndex == bloc.template.items.length - 1
                      ? null
                      : () => _goToIndex(_currentItemIndex + 1),
                ),
              ],
            ),
    );
  }

  Widget _buildItemCard(InspectionBloc bloc, Inspection inspection) {
    final item = _currentItem!;
    final response = inspection.responseFor(item.id)!;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.fullLabel,
              key: const Key('item-full-label'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _StatusSelector(
              statuses: item.statuses,
              selected: response.status,
              onSelected: (status) =>
                  unawaited(bloc.setItemStatus(item.id, status)),
            ),
            if (item.photosEnabled) ...[
              const SizedBox(height: 22),
              Text(
                item.photoBlocks.isEmpty
                    ? '${item.id} Photographs'
                    : item.photoBlocks.first.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              _PhotoGrid(
                photos: response.photos,
                defaultSlots: item.defaultPhotoSlots,
                onCapture: () => _capturePhoto(bloc, item),
                onDelete: (photo) =>
                    unawaited(_deletePhoto(bloc, item.id, photo)),
              ),
            ],
            if (item.commentsEnabled) ...[
              const SizedBox(height: 22),
              Text(
                'Observations and Recommendations',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('comments-field'),
                controller: _commentsController,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Record field observations and recommended action.',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => _scheduleCommentsSave(bloc, item, value),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _scheduleCommentsSave(
    InspectionBloc bloc,
    InspectionItem item,
    String value,
  ) {
    _commentsTimer?.cancel();
    _commentsTimer = Timer(const Duration(milliseconds: 300), () {
      _lastPersistedComments = value;
      unawaited(bloc.setComments(item.id, value));
    });
  }

  void _flushComments() {
    _commentsTimer?.cancel();
    final item = _currentItem;
    if (item != null && _commentsController.text != _lastPersistedComments) {
      _lastPersistedComments = _commentsController.text;
      unawaited(_bloc?.setComments(item.id, _commentsController.text));
    }
  }

  void _goToItem(String itemId) {
    final index = _bloc!.template.items.indexWhere((item) => item.id == itemId);
    if (index >= 0) _goToIndex(index);
  }

  void _goToIndex(int index) {
    _flushComments();
    final inspection = _bloc!.activeInspection;
    final nextItem = _bloc!.template.items[index];
    final comments = inspection?.responseFor(nextItem.id)?.comments ?? '';
    setState(() {
      _currentItemIndex = index;
      _commentsController.text = comments;
      _lastPersistedComments = comments;
    });
  }

  Future<void> _capturePhoto(InspectionBloc bloc, InspectionItem item) async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );
      if (image == null) return;
      final paths = await _photoStorage.preserve(
        inspectionId: widget.inspectionId,
        itemId: item.id,
        sourcePath: image.path,
      );
      await bloc.addPhoto(
        item.id,
        paths.originalPath,
        reportPath: paths.reportPath,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera unavailable. Check camera permissions.'),
        ),
      );
    }
  }

  Future<void> _deletePhoto(
    InspectionBloc bloc,
    String itemId,
    PhotoAttachment photo,
  ) async {
    await bloc.deletePhoto(itemId, photo.id);
    await _photoStorage.delete(
      StoredPhotoPaths(
        originalPath: photo.originalPath,
        reportPath: photo.reportPath,
      ),
    );
  }
}

class _SiteFields extends StatelessWidget {
  const _SiteFields({
    required this.fields,
    required this.controllers,
    required this.onChanged,
  });

  final List<SiteInfoField> fields;
  final Map<String, TextEditingController> controllers;
  final void Function(String fieldId, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Site details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final fieldWidth = constraints.maxWidth >= 620
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 14,
                  children: [
                    for (final field in fields)
                      SizedBox(
                        width: fieldWidth,
                        child: TextField(
                          key: Key('site-field-${field.id}'),
                          controller: controllers[field.id],
                          keyboardType: field.numeric
                              ? TextInputType.number
                              : field.type == 'date'
                              ? TextInputType.datetime
                              : TextInputType.text,
                          inputFormatters: field.numeric
                              ? [FilteringTextInputFormatter.digitsOnly]
                              : null,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: field.label,
                            hintText: field.example,
                          ),
                          onChanged: (value) => onChanged(field.id, value),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.sections,
    required this.inspection,
    required this.currentItemId,
    required this.onSelect,
  });

  final List<InspectionSection> sections;
  final Inspection inspection;
  final String currentItemId;
  final ValueChanged<InspectionItem> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final section in sections)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: PageStorageKey<String>('section-${section.id}'),
                initiallyExpanded: section.items.any(
                  (item) => item.id == currentItemId,
                ),
                title: Text(section.title),
                children: [
                  for (final item in section.items)
                    ListTile(
                      selected: item.id == currentItemId,
                      minTileHeight: 48,
                      leading: Icon(
                        inspection.responseFor(item.id)?.status == null
                            ? Icons.radio_button_unchecked
                            : Icons.check_circle,
                      ),
                      title: Text('${item.id} ${item.title}'),
                      onTap: () => onSelect(item),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({
    required this.statuses,
    required this.selected,
    required this.onSelected,
  });

  final List<String> statuses;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in statuses)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: ChoiceChip(
              key: Key('status-$status'),
              selected: selected == status,
              showCheckmark: false,
              label: Text('${selected == status ? '☑' : '☐'} $status'),
              onSelected: (_) => onSelected(status),
            ),
          ),
      ],
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.defaultSlots,
    required this.onCapture,
    required this.onDelete,
  });

  final List<PhotoAttachment> photos;
  final int defaultSlots;
  final VoidCallback onCapture;
  final ValueChanged<PhotoAttachment> onDelete;

  @override
  Widget build(BuildContext context) {
    final emptySlots = math.max(0, defaultSlots - photos.length);
    final itemCount = photos.length + emptySlots + 1;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 720 ? 4 : 3;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index < photos.length) {
              final photo = photos[index];
              return _PhotoTile(photo: photo, onDelete: onDelete);
            }
            if (index < photos.length + emptySlots) {
              return _CaptureTile(
                key: Key('empty-photo-slot-$index'),
                label: 'PHOTO ${index + 1}',
                onTap: onCapture,
              );
            }
            return _CaptureTile(
              key: const Key('add-photo-button'),
              label: '+ ADD PHOTO',
              onTap: onCapture,
              emphasized: true,
            );
          },
        );
      },
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onDelete});

  final PhotoAttachment photo;
  final ValueChanged<PhotoAttachment> onDelete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.file(
            File(photo.reportPath),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: IconButton.filled(
            tooltip: 'Delete photo',
            onPressed: () => onDelete(photo),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ],
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    super.key,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: emphasized ? colors.primaryContainer : colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.current,
    required this.total,
    required this.onPrevious,
    required this.onNext,
  });

  final int current;
  final int total;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

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
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('PREVIOUS'),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('$current / $total'),
            ),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: onNext,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('NEXT'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingOrError extends StatelessWidget {
  const _LoadingOrError({required this.isLoading, required this.retry});

  final bool isLoading;
  final Future<Inspection?> Function() retry;

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Inspection could not be loaded.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
