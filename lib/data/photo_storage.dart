import 'dart:io';

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
  PhotoStorage({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  Future<StoredPhotoPaths> preserve({
    required String inspectionId,
    required String itemId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Captured photo was not found.', sourcePath);
    }

    final documents = await getApplicationDocumentsDirectory();
    final safeItemId = itemId.replaceAll(RegExp('[^A-Za-z0-9._-]'), '_');
    final directory = Directory(
      path.join(documents.path, 'inspection_photos', inspectionId, safeItemId),
    );
    await directory.create(recursive: true);

    final sourceExtension = path.extension(sourcePath).toLowerCase();
    final extension = sourceExtension.isEmpty ? '.jpg' : sourceExtension;
    final destination = path.join(directory.path, '${_uuid.v4()}$extension');
    final preserved = await source.copy(destination);
    return StoredPhotoPaths(
      originalPath: preserved.path,
      reportPath: preserved.path,
    );
  }

  Future<void> delete(StoredPhotoPaths paths) async {
    final targets = {paths.originalPath, paths.reportPath};
    for (final target in targets) {
      final file = File(target);
      if (await file.exists()) await file.delete();
    }
  }
}
