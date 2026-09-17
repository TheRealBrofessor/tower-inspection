import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class StoredPhotoPaths {
  const StoredPhotoPaths({
    required this.originalPath,
    required this.reportPath,
  });

  final String originalPath;
  final String reportPath;
}

class PhotoStorage {
  PhotoStorage({Uuid? uuid, Future<Directory> Function()? documentsDirectory})
    : _uuid = uuid ?? const Uuid(),
      _documentsDirectory =
          documentsDirectory ?? getApplicationDocumentsDirectory;

  final Uuid _uuid;
  final Future<Directory> Function() _documentsDirectory;

  Future<StoredPhotoPaths> preserve({
    required String inspectionId,
    required String itemId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Captured photo was not found.', sourcePath);
    }

    final documents = await _documentsDirectory();
    final safeItemId = itemId.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final directory = Directory(
      path.join(documents.path, 'inspection_photos', inspectionId, safeItemId),
    );
    await directory.create(recursive: true);

    final id = _uuid.v4();
    final sourceExtension = path.extension(sourcePath).toLowerCase();
    final extension = sourceExtension.isEmpty ? '.jpg' : sourceExtension;
    final originalPath = path.join(directory.path, '$id$extension');
    final reportPath = path.join(directory.path, '${id}_report.jpg');
    try {
      final preserved = await source.copy(originalPath);
      final decoded = image.decodeImage(await preserved.readAsBytes());
      if (decoded == null) {
        throw const FormatException('Captured photo could not be decoded.');
      }
      final oriented = image.bakeOrientation(decoded);
      final longestEdge = oriented.width > oriented.height
          ? oriented.width
          : oriented.height;
      final reportImage = longestEdge > 1000
          ? image.copyResize(
              oriented,
              width: oriented.width >= oriented.height ? 1000 : null,
              height: oriented.height > oriented.width ? 1000 : null,
              interpolation: image.Interpolation.average,
            )
          : oriented;
      await File(reportPath)
          .writeAsBytes(image.encodeJpg(reportImage, quality: 80), flush: true);
      return StoredPhotoPaths(
        originalPath: preserved.path,
        reportPath: reportPath,
      );
    } catch (_) {
      await _deleteIfPresent(originalPath);
      await _deleteIfPresent(reportPath);
      rethrow;
    }
  }

  Future<void> delete(StoredPhotoPaths paths) async {
    final targets = {paths.originalPath, paths.reportPath};
    for (final target in targets) {
      await _deleteIfPresent(target);
    }
  }

  Future<void> _deleteIfPresent(String target) async {
    final file = File(target);
    if (await file.exists()) await file.delete();
  }
}
