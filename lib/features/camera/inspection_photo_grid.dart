import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/photo_storage.dart';
import '../../domain/models.dart';
import '../inspections/inspection_bloc.dart';

class InspectionPhotoGrid extends StatefulWidget {
  const InspectionPhotoGrid({
    super.key,
    required this.inspectionId,
    required this.item,
    required this.photos,
    required this.bloc,
    this.imagePicker,
    this.photoStorage,
  });

  final String inspectionId;
  final InspectionItem item;
  final List<PhotoAttachment> photos;
  final InspectionBloc bloc;
  final ImagePicker? imagePicker;
  final PhotoStorage? photoStorage;

  @override
  State<InspectionPhotoGrid> createState() => _InspectionPhotoGridState();
}

class _InspectionPhotoGridState extends State<InspectionPhotoGrid> {
  late final ImagePicker _imagePicker = widget.imagePicker ?? ImagePicker();
  late final PhotoStorage _photoStorage = widget.photoStorage ?? PhotoStorage();
  final Map<String, int> _slotCounts = {};

  int get _slotCount {
    final minimum = math.max(
      3,
      math.max(widget.item.defaultPhotoSlots, widget.photos.length),
    );
    return math.max(_slotCounts[widget.item.id] ?? minimum, minimum);
  }

  @override
  Widget build(BuildContext context) {
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
          itemCount: _slotCount + 1,
          itemBuilder: (context, index) {
            if (index < widget.photos.length) {
              final photo = widget.photos[index];
              return _PhotoTile(
                key: Key('photo-${photo.id}'),
                photo: photo,
                order: index + 1,
                onTap: () => _managePhoto(photo, index),
              );
            }
            if (index < _slotCount) {
              return _CaptureTile(
                key: Key('empty-photo-slot-$index'),
                order: index + 1,
                label: 'TAP TO TAKE PHOTO',
                onTap: () => _captureNewPhoto(),
              );
            }
            return _CaptureTile(
              key: const Key('add-photo-button'),
              label: '+ ADD PHOTO',
              emphasized: true,
              onTap: () {
                setState(() {
                  _slotCounts[widget.item.id] = _slotCount + 1;
                });
              },
            );
          },
        );
      },
    );
  }

  Future<void> _captureNewPhoto() async {
    final paths = await _pickAndPreserve(ImageSource.camera);
    if (paths == null) return;
    final saved = await widget.bloc.addPhoto(
      widget.item.id,
      paths.originalPath,
      reportPath: paths.reportPath,
    );
    if (!saved) {
      await _deleteFiles(paths);
      _showMessage('Photo could not be saved. Please try again.');
    }
  }

  Future<void> _managePhoto(PhotoAttachment photo, int index) async {
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Photo ${index + 1}'),
              subtitle: Text(
                'Captured ${DateFormat.yMMMd().add_jm().format(photo.capturedAt.toLocal())}',
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.fullscreen),
              title: const Text('View full-screen'),
              onTap: () => Navigator.pop(context, _PhotoAction.view),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Retake with camera'),
              onTap: () => Navigator.pop(context, _PhotoAction.retake),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Replace from photos'),
              onTap: () => Navigator.pop(context, _PhotoAction.replace),
            ),
            ListTile(
              leading: const Icon(Icons.arrow_back),
              title: const Text('Move left'),
              enabled: index > 0,
              onTap: index > 0
                  ? () => Navigator.pop(context, _PhotoAction.moveLeft)
                  : null,
            ),
            ListTile(
              leading: const Icon(Icons.arrow_forward),
              title: const Text('Move right'),
              enabled: index < widget.photos.length - 1,
              onTap: index < widget.photos.length - 1
                  ? () => Navigator.pop(context, _PhotoAction.moveRight)
                  : null,
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete photo',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, _PhotoAction.delete),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PhotoAction.view:
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => _FullScreenPhoto(photo: photo),
          ),
        );
      case _PhotoAction.retake:
        await _replacePhoto(photo, ImageSource.camera);
      case _PhotoAction.replace:
        await _replacePhoto(photo, ImageSource.gallery);
      case _PhotoAction.moveLeft:
        await _movePhoto(index, index - 1);
      case _PhotoAction.moveRight:
        await _movePhoto(index, index + 1);
      case _PhotoAction.delete:
        await _confirmDelete(photo);
    }
  }

  Future<void> _replacePhoto(
    PhotoAttachment current,
    ImageSource source,
  ) async {
    final replacement = await _pickAndPreserve(source);
    if (replacement == null) return;
    final saved = await widget.bloc.replacePhoto(
      widget.item.id,
      current,
      replacement.originalPath,
      replacement.reportPath,
    );
    if (!saved) {
      await _deleteFiles(replacement);
      _showMessage('Replacement photo could not be saved.');
      return;
    }
    await _deleteFiles(
      StoredPhotoPaths(
        originalPath: current.originalPath,
        reportPath: current.reportPath,
      ),
    );
  }

  Future<void> _movePhoto(int from, int to) async {
    final ids = widget.photos.map((photo) => photo.id).toList();
    final moved = ids.removeAt(from);
    ids.insert(to, moved);
    final saved = await widget.bloc.reorderPhotos(widget.item.id, ids);
    if (!saved) _showMessage('Photo order could not be updated.');
  }

  Future<void> _confirmDelete(PhotoAttachment photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete photo?'),
        content: const Text('This permanently removes this inspection photo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.bloc.deletePhoto(widget.item.id, photo.id);
    if (!deleted) {
      _showMessage('Photo could not be deleted.');
      return;
    }
    await _deleteFiles(
      StoredPhotoPaths(
        originalPath: photo.originalPath,
        reportPath: photo.reportPath,
      ),
    );
  }

  Future<StoredPhotoPaths?> _pickAndPreserve(ImageSource source) async {
    try {
      if (!await _requestPermission(source)) return null;
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return null;
      return await _photoStorage.preserve(
        inspectionId: widget.inspectionId,
        itemId: widget.item.id,
        sourcePath: picked.path,
      );
    } on PlatformException {
      _showMessage('Photo access failed. Check app permissions and try again.');
      return null;
    } on FileSystemException {
      _showMessage(
        'Photo could not be stored. Check available device storage.',
      );
      return null;
    } on FormatException {
      _showMessage('The selected image could not be processed.');
      return null;
    } catch (_) {
      _showMessage('Photo could not be captured. Your inspection is safe.');
      return null;
    }
  }

  Future<bool> _requestPermission(ImageSource source) async {
    final permission = source == ImageSource.camera
        ? Permission.camera
        : Permission.photos;
    var status = await permission.request();
    if (source == ImageSource.gallery &&
        Platform.isAndroid &&
        !status.isGranted &&
        !status.isLimited) {
      status = await Permission.storage.request();
    }
    if (status.isGranted || status.isLimited) return true;
    if (!mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          source == ImageSource.camera
              ? 'Camera permission needed'
              : 'Photo permission needed',
        ),
        content: const Text(
          'Allow access in app settings, then return to continue this inspection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('NOT NOW'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await openAppSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
    return false;
  }

  Future<void> _deleteFiles(StoredPhotoPaths paths) async {
    try {
      await _photoStorage.delete(paths);
    } on FileSystemException {
      _showMessage('Photo files could not be removed from device storage.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

enum _PhotoAction { view, retake, replace, moveLeft, moveRight, delete }

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({
    super.key,
    required this.photo,
    required this.order,
    required this.onTap,
  });

  final PhotoAttachment photo;
  final int order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(
              File(photo.reportPath),
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            Positioned(top: 6, left: 6, child: _OrderBadge(order: order)),
          ],
        ),
      ),
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({
    super.key,
    required this.label,
    required this.onTap,
    this.order,
    this.emphasized = false,
  });

  final String label;
  final VoidCallback onTap;
  final int? order;
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
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
            ),
            if (order != null)
              Positioned(top: 6, left: 6, child: _OrderBadge(order: order!)),
          ],
        ),
      ),
    );
  }
}

class _OrderBadge extends StatelessWidget {
  const _OrderBadge({required this.order});

  final int order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$order',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.photo});

  final PhotoAttachment photo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          DateFormat.yMMMd().add_jm().format(photo.capturedAt.toLocal()),
        ),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.file(
            File(photo.originalPath),
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
      ),
    );
  }
}
