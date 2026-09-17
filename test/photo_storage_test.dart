import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:path/path.dart' as path;
import 'package:tower_inspection/data/photo_storage.dart';

void main() {
  test('preserves the original and creates a 1000px JPEG derivative', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'tower-photo-storage-',
    );
    try {
      final sourcePath = path.join(temporaryDirectory.path, 'source.png');
      final sourceBytes = image.encodePng(
        image.Image(width: 1600, height: 800),
      );
      await File(sourcePath).writeAsBytes(sourceBytes);
      final documents = Directory(
        path.join(temporaryDirectory.path, 'documents'),
      );
      final storage = PhotoStorage(documentsDirectory: () async => documents);

      final stored = await storage.preserve(
        inspectionId: 'inspection-1',
        itemId: 'A.1',
        sourcePath: sourcePath,
      );
      final report = image.decodeJpg(
        await File(stored.reportPath).readAsBytes(),
      );

      expect(stored.originalPath, isNot(stored.reportPath));
      expect(await File(stored.originalPath).readAsBytes(), sourceBytes);
      expect(report, isNotNull);
      expect(report!.width, 1000);
      expect(report.height, 500);

      await storage.delete(stored);
      expect(File(stored.originalPath).existsSync(), isFalse);
      expect(File(stored.reportPath).existsSync(), isFalse);
    } finally {
      await temporaryDirectory.delete(recursive: true);
    }
  });
}
