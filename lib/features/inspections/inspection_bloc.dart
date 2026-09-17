import 'package:flutter/foundation.dart';

import '../../data/inspection_repository.dart';
import '../../domain/models.dart';

class InspectionBloc extends ChangeNotifier {
  InspectionBloc({required this.template, required this.repository});

  final InspectionTemplate template;
  final InspectionRepository repository;

  List<Inspection> drafts = const [];
  List<Inspection> inProgress = const [];
  List<Inspection> readyForReview = const [];
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
        repository.listInspectionsByStatus(Inspection.inProgressStatus),
        repository.listInspectionsByStatus(Inspection.readyForReviewStatus),
        repository.listInspectionsByStatus(Inspection.completedStatus),
      ]);
      drafts = results[0];
      inProgress = results[1];
      readyForReview = results[2];
      completed = results[3];
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
      status: _statusAfterEdit(inspection.status),
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

  Future<bool> addPhoto(
    String itemId,
    String originalPath, {
    String? reportPath,
  }) async {
    final inspection = activeInspection;
    if (inspection == null) return false;
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
      return true;
    } catch (error) {
      _recordError(error);
      return false;
    }
  }

  Future<bool> deletePhoto(String itemId, String photoId) async {
    final inspection = activeInspection;
    if (inspection == null) return false;
    final response = inspection.responseFor(itemId);
    if (response == null) return false;
    final remaining = response.photos
        .where((photo) => photo.id != photoId)
        .toList(growable: false);
    try {
      await repository.deletePhoto(photoId);
      _updateResponse(
        itemId,
        (current) => current.copyWith(
          photos: [
            for (var index = 0; index < remaining.length; index++)
              remaining[index].copyWith(orderIndex: index),
          ],
        ),
      );
      return true;
    } catch (error) {
      _recordError(error);
      return false;
    }
  }

  Future<bool> reorderPhotos(String itemId, List<String> photoIds) async {
    final inspection = activeInspection;
    final response = inspection?.responseFor(itemId);
    if (inspection == null || response == null) return false;
    final byId = {for (final photo in response.photos) photo.id: photo};
    try {
      await repository.reorderPhotos(inspection.id, itemId, photoIds);
      _updateResponse(
        itemId,
        (current) => current.copyWith(
          photos: [
            for (var index = 0; index < photoIds.length; index++)
              byId[photoIds[index]]!.copyWith(orderIndex: index),
          ],
        ),
      );
      return true;
    } catch (error) {
      _recordError(error);
      return false;
    }
  }

  Future<bool> replacePhoto(
    String itemId,
    PhotoAttachment current,
    String originalPath,
    String reportPath,
  ) async {
    try {
      final replacement = await repository.replacePhoto(
        photoId: current.id,
        originalPath: originalPath,
        reportPath: reportPath,
      );
      _updateResponse(
        itemId,
        (response) => response.copyWith(
          photos: [
            for (final photo in response.photos)
              if (photo.id == current.id) replacement else photo,
          ],
        ),
      );
      return true;
    } catch (error) {
      _recordError(error);
      return false;
    }
  }

  Future<bool> markReadyForReview() async {
    final inspection = activeInspection;
    if (inspection == null) return false;
    try {
      var status = inspection.status;
      if (status == InspectionStatus.draft) {
        await repository.updateInspectionStatus(
          inspection.id,
          InspectionStatus.inProgress,
        );
        status = InspectionStatus.inProgress;
      }
      if (status != InspectionStatus.inProgress) return false;
      await repository.updateInspectionStatus(
        inspection.id,
        InspectionStatus.readyForReview,
      );
      _setActiveStatus(InspectionStatus.readyForReview);
      return true;
    } catch (error) {
      _recordError(error);
      return false;
    }
  }

  Future<bool> markCompleted() async {
    final inspection = activeInspection;
    if (inspection == null ||
        inspection.status != InspectionStatus.readyForReview) {
      return false;
    }
    try {
      await repository.updateInspectionStatus(
        inspection.id,
        InspectionStatus.completed,
      );
      _setActiveStatus(InspectionStatus.completed);
      return true;
    } catch (error) {
      _recordError(error);
      return false;
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
      status: _statusAfterEdit(inspection.status),
      responses: responses,
      updatedAt: DateTime.now().toUtc(),
    );
    _replaceInLists(activeInspection!);
    notifyListeners();
  }

  void _replaceInLists(Inspection inspection) {
    final all = {
      for (final item in [
        ...drafts,
        ...inProgress,
        ...readyForReview,
        ...completed,
      ])
        item.id: item,
      inspection.id: inspection,
    }.values;
    drafts = [
      for (final item in all)
        if (item.status == InspectionStatus.draft) item,
    ];
    inProgress = [
      for (final item in all)
        if (item.status == InspectionStatus.inProgress) item,
    ];
    readyForReview = [
      for (final item in all)
        if (item.status == InspectionStatus.readyForReview) item,
    ];
    completed = [
      for (final item in all)
        if (item.status == InspectionStatus.completed) item,
    ];
  }

  InspectionStatus _statusAfterEdit(InspectionStatus status) =>
      status == InspectionStatus.draft ? InspectionStatus.inProgress : status;

  void _setActiveStatus(InspectionStatus status) {
    final inspection = activeInspection;
    if (inspection == null) return;
    activeInspection = inspection.copyWith(
      status: status,
      updatedAt: DateTime.now().toUtc(),
    );
    _replaceInLists(activeInspection!);
    notifyListeners();
  }

  void _recordError(Object error) {
    lastError = error;
    notifyListeners();
  }
}
