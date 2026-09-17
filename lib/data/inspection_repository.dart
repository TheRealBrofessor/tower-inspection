import 'dart:convert';

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../domain/models.dart';
import 'database.dart';

class InspectionRepository {
  InspectionRepository(
    this._appDatabase, {
    Uuid? uuid,
    DateTime Function()? now,
  }) : _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  final AppDatabase _appDatabase;
  final Uuid _uuid;
  final DateTime Function() _now;

  Future<Inspection> createInspection(InspectionTemplate template) async {
    final database = await _appDatabase.database;
    final id = _uuid.v4();
    final localNow = _now();
    final timestamp = localNow.toUtc().toIso8601String();
    final siteFields = <String, String>{};

    for (final field in template.siteInfoFields) {
      var value = field.defaultValue ?? '';
      if (value.isEmpty && field.type == 'date') {
        value = DateFormat('M/d/yyyy').format(localNow);
      }
      siteFields[field.id] = value;
    }

    await database.transaction((transaction) async {
      await transaction.insert('inspections', {
        'id': id,
        'template_version': template.templateVersion,
        'site_name': siteFields['siteName'] ?? '',
        'asr': siteFields['asr'] ?? '',
        'prepared_for': siteFields['preparedFor'] ?? '',
        'inspection_date': siteFields['inspectionDate'] ?? '',
        'status': Inspection.draftStatus,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      for (final item in template.items) {
        await transaction.insert('item_responses', {
          'inspection_id': id,
          'item_id': item.id,
          'status': null,
          'comments': item.prefilledObservation,
        });
      }
    });

    return (await getInspection(id))!;
  }

  Future<Inspection?> getInspection(String id) async {
    final database = await _appDatabase.database;
    final inspectionRows = await database.query(
      'inspections',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (inspectionRows.isEmpty) return null;

    final responseRows = await database.query(
      'item_responses',
      where: 'inspection_id = ?',
      whereArgs: [id],
      orderBy: 'item_id ASC',
    );
    final photoRows = await database.query(
      'photo_attachments',
      where: 'inspection_id = ?',
      whereArgs: [id],
      orderBy: 'item_id ASC, order_index ASC',
    );

    final photosByItem = <String, List<PhotoAttachment>>{};
    for (final row in photoRows) {
      final photo = _photoFromRow(row);
      photosByItem.putIfAbsent(photo.itemId, () => []).add(photo);
    }

    final responses = responseRows
        .map(
          (row) => InspectionItemResponse(
            inspectionId: row['inspection_id']! as String,
            itemId: row['item_id']! as String,
            status: row['status'] as String?,
            comments: row['comments']! as String,
            photos: List.unmodifiable(
              photosByItem[row['item_id'] as String] ??
                  const <PhotoAttachment>[],
            ),
          ),
        )
        .toList(growable: false);

    return _inspectionFromRow(inspectionRows.single, responses);
  }

  Future<void> updateSiteField(
    String inspectionId,
    String fieldId,
    String value,
  ) async {
    final database = await _appDatabase.database;
    final timestamp = _timestamp();
    final values = switch (fieldId) {
      'siteName' => {'site_name': value, 'updated_at': timestamp},
      'asr' => {'asr': value, 'updated_at': timestamp},
      'preparedFor' => {'prepared_for': value, 'updated_at': timestamp},
      'inspectionDate' => {'inspection_date': value, 'updated_at': timestamp},
      _ => throw ArgumentError.value(fieldId, 'fieldId', 'Unknown site field'),
    };
    await database.update(
      'inspections',
      values,
      where: 'id = ?',
      whereArgs: [inspectionId],
    );
  }

  Future<void> setStatus(
    String inspectionId,
    String itemId,
    String status,
  ) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.update(
        'item_responses',
        {'status': status},
        where: 'inspection_id = ? AND item_id = ?',
        whereArgs: [inspectionId, itemId],
      );
      await _touch(transaction, inspectionId);
    });
  }

  Future<void> setComments(
    String inspectionId,
    String itemId,
    String comments,
  ) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      await transaction.update(
        'item_responses',
        {'comments': comments},
        where: 'inspection_id = ? AND item_id = ?',
        whereArgs: [inspectionId, itemId],
      );
      await _touch(transaction, inspectionId);
    });
  }

  Future<PhotoAttachment> addPhoto({
    required String inspectionId,
    required String itemId,
    required String originalPath,
    String? reportPath,
    DateTime? capturedAt,
    JsonMap metadata = const <String, dynamic>{},
  }) async {
    final database = await _appDatabase.database;
    final photo = await database.transaction((transaction) async {
      final nextRows = await transaction.rawQuery(
        '''
          SELECT COALESCE(MAX(order_index), -1) + 1 AS next_index
          FROM photo_attachments
          WHERE inspection_id = ? AND item_id = ?
        ''',
        [inspectionId, itemId],
      );
      final nextIndex = nextRows.single['next_index']! as int;
      final attachment = PhotoAttachment(
        id: _uuid.v4(),
        inspectionId: inspectionId,
        itemId: itemId,
        orderIndex: nextIndex,
        originalPath: originalPath,
        reportPath: reportPath ?? originalPath,
        capturedAt: (capturedAt ?? _now()).toUtc(),
        metadata: metadata,
      );
      await transaction.insert('photo_attachments', {
        'id': attachment.id,
        'inspection_id': attachment.inspectionId,
        'item_id': attachment.itemId,
        'order_index': attachment.orderIndex,
        'original_path': attachment.originalPath,
        'report_path': attachment.reportPath,
        'captured_at': attachment.capturedAt.toIso8601String(),
        'metadata_json': jsonEncode(attachment.metadata),
      });
      await _touch(transaction, inspectionId);
      return attachment;
    });
    return photo;
  }

  Future<void> deletePhoto(String photoId) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final targetRows = await transaction.query(
        'photo_attachments',
        columns: ['inspection_id', 'item_id'],
        where: 'id = ?',
        whereArgs: [photoId],
        limit: 1,
      );
      if (targetRows.isEmpty) return;
      final inspectionId = targetRows.single['inspection_id']! as String;
      final itemId = targetRows.single['item_id']! as String;
      await transaction.delete(
        'photo_attachments',
        where: 'id = ?',
        whereArgs: [photoId],
      );
      final remaining = await transaction.query(
        'photo_attachments',
        columns: ['id'],
        where: 'inspection_id = ? AND item_id = ?',
        whereArgs: [inspectionId, itemId],
        orderBy: 'order_index ASC',
      );
      for (var index = 0; index < remaining.length; index++) {
        await transaction.update(
          'photo_attachments',
          {'order_index': index},
          where: 'id = ?',
          whereArgs: [remaining[index]['id']],
        );
      }
      await _touch(transaction, inspectionId);
    });
  }

  Future<void> reorderPhotos(
    String inspectionId,
    String itemId,
    List<String> photoIds,
  ) async {
    final database = await _appDatabase.database;
    await database.transaction((transaction) async {
      final currentRows = await transaction.query(
        'photo_attachments',
        columns: ['id'],
        where: 'inspection_id = ? AND item_id = ?',
        whereArgs: [inspectionId, itemId],
      );
      final currentIds = currentRows.map((row) => row['id']! as String).toSet();
      if (currentIds.length != photoIds.length ||
          !currentIds.containsAll(photoIds) ||
          photoIds.toSet().length != photoIds.length) {
        throw ArgumentError('Photo order must contain every item photo once.');
      }

      for (var index = 0; index < photoIds.length; index++) {
        await transaction.update(
          'photo_attachments',
          {'order_index': -index - 1},
          where: 'id = ?',
          whereArgs: [photoIds[index]],
        );
      }
      for (var index = 0; index < photoIds.length; index++) {
        await transaction.update(
          'photo_attachments',
          {'order_index': index},
          where: 'id = ?',
          whereArgs: [photoIds[index]],
        );
      }
      await _touch(transaction, inspectionId);
    });
  }

  Future<List<Inspection>> listInspectionsByStatus(String status) async {
    final database = await _appDatabase.database;
    final rows = await database.query(
      'inspections',
      where: 'status = ?',
      whereArgs: [status],
      orderBy: 'updated_at DESC',
    );
    final inspections = <Inspection>[];
    for (final row in rows) {
      final inspection = await getInspection(row['id']! as String);
      if (inspection != null) inspections.add(inspection);
    }
    return inspections;
  }

  Inspection _inspectionFromRow(
    Map<String, Object?> row,
    List<InspectionItemResponse> responses,
  ) => Inspection(
    id: row['id']! as String,
    templateVersion: row['template_version']! as String,
    siteFields: {
      'siteName': row['site_name']! as String,
      'asr': row['asr']! as String,
      'preparedFor': row['prepared_for']! as String,
      'inspectionDate': row['inspection_date']! as String,
    },
    status: row['status']! as String,
    createdAt: DateTime.parse(row['created_at']! as String),
    updatedAt: DateTime.parse(row['updated_at']! as String),
    responses: responses,
  );

  PhotoAttachment _photoFromRow(Map<String, Object?> row) => PhotoAttachment(
    id: row['id']! as String,
    inspectionId: row['inspection_id']! as String,
    itemId: row['item_id']! as String,
    orderIndex: row['order_index']! as int,
    originalPath: row['original_path']! as String,
    reportPath: row['report_path']! as String,
    capturedAt: DateTime.parse(row['captured_at']! as String),
    metadata: _decodeMetadata(row['metadata_json']! as String),
  );

  JsonMap _decodeMetadata(String value) {
    final decoded = jsonDecode(value);
    return decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
  }

  String _timestamp() => _now().toUtc().toIso8601String();

  Future<void> _touch(DatabaseExecutor executor, String inspectionId) =>
      executor.update(
        'inspections',
        {'updated_at': _timestamp()},
        where: 'id = ?',
        whereArgs: [inspectionId],
      );
}
