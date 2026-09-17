import 'package:flutter/foundation.dart';

import '../../data/inspection_repository.dart';
import '../../domain/models.dart';

class InspectionBloc extends ChangeNotifier {
  InspectionBloc({required this.template, required this.repository});

  final InspectionTemplate template;
  final InspectionRepository repository;

  List<Inspection> drafts = const [];
  List<Inspection> completed = const [];
  Inspection? activeInspection;
  bool isLoading = false;
  Object? lastError;

  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        repository.listInspectionsByStatus(Inspection.draftStatus),
        repository.listInspectionsByStatus(Inspection.completedStatus),
      ]);
      drafts = results[0];
      completed = results[1];
      lastError = null;
    } catch (error) {
      lastError = error;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<Inspection> createInspection() async {
    final inspection = await repository.createInspection(template);
    activeInspection = inspection;
    drafts = [inspection, ...drafts];
    lastError = null;
    notifyListeners();
    return inspection;
  }

  Future<Inspection?> openInspection(String inspectionId) async {
    isLoading = true;
    notifyListeners();
    try {
      activeInspection = await repository.getInspection(inspectionId);
      lastError = null;
      return activeInspection;
    } catch (error) {
      lastError = error;
      return null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateSiteField(String fieldId, String value) async {
    final inspection = activeInspection;
    if (inspection == null) return;
    final fields = Map<String, String>.from(inspection.siteFields);
    fields[fieldId] = value;
    activeInspection = inspection.copyWith(
      siteFields: fields,
      updatedAt: DateTime.now().toUtc(),
    );
    _replaceInLists(activeInspection!);
    notifyListeners();
    try {
      await repository.updateSiteField(inspection.id, fieldId, value);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> setItemStatus(String itemId, String status) async {
    final inspection = activeInspection;
    if (inspection == null) return;
    _updateResponse(itemId, (response) => response.copyWith(status: status));
    try {
      await repository.setStatus(inspection.id, itemId, status);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> setComments(String itemId, String comments) async {
    final inspection = activeInspection;
    if (inspection == null) return;
    _updateResponse(
      itemId,
      (response) => response.copyWith(comments: comments),
    );
    try {
      await repository.setComments(inspection.id, itemId, comments);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> addPhoto(
    String itemId,
    String originalPath, {
    String? reportPath,
  }) async {
    final inspection = activeInspection;
    if (inspection == null) return;
    try {
      final photo = await repository.addPhoto(
        inspectionId: inspection.id,
        itemId: itemId,
        originalPath: originalPath,
        reportPath: reportPath,
      );
      _updateResponse(
        itemId,
        (response) => response.copyWith(photos: [...response.photos, photo]),
      );
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> deletePhoto(String itemId, String photoId) async {
    final inspection = activeInspection;
    if (inspection == null) return;
    final response = inspection.responseFor(itemId);
    if (response == null) return;
    final remaining = response.photos
        .where((photo) => photo.id != photoId)
        .toList(growable: false);
    _updateResponse(
      itemId,
      (current) => current.copyWith(
        photos: [
          for (var index = 0; index < remaining.length; index++)
            remaining[index].copyWith(orderIndex: index),
        ],
      ),
    );
    try {
      await repository.deletePhoto(photoId);
    } catch (error) {
      _recordError(error);
    }
  }

  Future<void> reorderPhotos(String itemId, List<String> photoIds) async {
    final inspection = activeInspection;
    final response = inspection?.responseFor(itemId);
    if (inspection == null || response == null) return;
    final byId = {for (final photo in response.photos) photo.id: photo};
    _updateResponse(
      itemId,
      (current) => current.copyWith(
        photos: [
          for (var index = 0; index < photoIds.length; index++)
            byId[photoIds[index]]!.copyWith(orderIndex: index),
        ],
      ),
    );
    try {
      await repository.reorderPhotos(inspection.id, itemId, photoIds);
    } catch (error) {
      _recordError(error);
    }
  }

  void _updateResponse(
    String itemId,
    InspectionItemResponse Function(InspectionItemResponse) update,
  ) {
    final inspection = activeInspection;
    if (inspection == null) return;
    final responses = [
      for (final response in inspection.responses)
        if (response.itemId == itemId) update(response) else response,
    ];
    activeInspection = inspection.copyWith(
      responses: responses,
      updatedAt: DateTime.now().toUtc(),
    );
    _replaceInLists(activeInspection!);
    notifyListeners();
  }

  void _replaceInLists(Inspection inspection) {
    drafts = [
      for (final item in drafts)
        if (item.id == inspection.id) inspection else item,
    ];
    completed = [
      for (final item in completed)
        if (item.id == inspection.id) inspection else item,
    ];
  }

  void _recordError(Object error) {
    lastError = error;
    notifyListeners();
  }
}
