import '../../domain/models.dart';

const int reportPhotosPerBlock = 3;

enum ReportPageKind { cover, item }

enum ReportTextOverflow { preserve }

class ReportLayout {
  const ReportLayout({
    required this.title,
    required this.header,
    required this.cover,
    required this.contractor,
    required this.items,
    required this.pages,
  });

  factory ReportLayout.build({
    required InspectionTemplate template,
    required Inspection inspection,
  }) {
    final header = ReportHeaderSpec(
      siteName: inspection.siteFields['siteName']?.trim() ?? '',
      inspectionDate: inspection.siteFields['inspectionDate']?.trim() ?? '',
      asr: inspection.siteFields['asr']?.trim() ?? '',
    );
    final contractor = ReportContractorSpec(
      name: template.contractor.name,
      address: template.contractor.address,
      cityStateZip: template.contractor.cityStateZip,
    );
    final cover = ReportCoverSpec(
      siteName: header.siteName,
      asr: header.asr,
      preparedFor: inspection.siteFields['preparedFor']?.trim() ?? '',
      address: inspection.siteFields['address']?.trim() ?? '',
      inspectionDate: header.inspectionDate,
    );
    final items = <ReportItemSpec>[];
    final pages = <ReportPage>[const ReportPage(kind: ReportPageKind.cover)];

    for (final section in template.sections) {
      for (var itemIndex = 0; itemIndex < section.items.length; itemIndex++) {
        final templateItem = section.items[itemIndex];
        final response = inspection.responseFor(templateItem.id);
        final orderedPhotos = [...?response?.photos]
          ..sort((left, right) => left.orderIndex.compareTo(right.orderIndex));
        final photoBlocks = templateItem.photosEnabled
            ? _buildPhotoBlocks(templateItem, orderedPhotos)
            : const <PhotoBlockSpec>[];
        final item = ReportItemSpec(
          sectionId: section.id,
          sectionTitle: section.title,
          showSectionHeader: itemIndex == 0,
          itemId: templateItem.id,
          title: templateItem.title,
          fullLabel: templateItem.fullLabel,
          status: StatusRowSpec.fromStatuses(
            templateItem.statuses,
            response?.status,
          ),
          observation: templateItem.commentsEnabled
              ? ObservationBlockSpec(
                  comments:
                      response?.comments ?? templateItem.prefilledObservation,
                )
              : null,
          photoBlocks: photoBlocks,
        );
        items.add(item);

        if (photoBlocks.isEmpty) {
          pages.add(
            ReportPage(
              kind: ReportPageKind.item,
              item: item,
              showItemHeader: true,
            ),
          );
        } else {
          for (
            var blockIndex = 0;
            blockIndex < photoBlocks.length;
            blockIndex++
          ) {
            pages.add(
              ReportPage(
                kind: ReportPageKind.item,
                item: item,
                photoBlock: photoBlocks[blockIndex],
                showItemHeader: blockIndex == 0,
              ),
            );
          }
        }
      }
    }

    return ReportLayout(
      title: template.reportTitle,
      header: header,
      cover: cover,
      contractor: contractor,
      items: List.unmodifiable(items),
      pages: List.unmodifiable(pages),
    );
  }

  final String title;
  final ReportHeaderSpec header;
  final ReportCoverSpec cover;
  final ReportContractorSpec contractor;
  final List<ReportItemSpec> items;
  final List<ReportPage> pages;

  Iterable<ReportPage> get bodyPages => pages.where((page) => !page.isCover);
}

ReportLayout buildReportLayout(
  InspectionTemplate template,
  Inspection inspection,
) => ReportLayout.build(template: template, inspection: inspection);

List<PhotoBlockSpec> _buildPhotoBlocks(
  InspectionItem item,
  List<PhotoAttachment> photos,
) {
  final blockCount = photos.isEmpty
      ? 1
      : (photos.length + reportPhotosPerBlock - 1) ~/ reportPhotosPerBlock;
  return List<PhotoBlockSpec>.unmodifiable([
    for (var blockIndex = 0; blockIndex < blockCount; blockIndex++)
      PhotoBlockSpec(
        blockNumber: blockIndex + 1,
        label: blockIndex == 0
            ? '${item.id}.1 ${item.title} - Photographs'
            : '${item.id}.${blockIndex + 1} ${item.title} '
                  '– Photographs (Continued)',
        continued: blockIndex > 0,
        slots: List<PhotoSlotSpec>.unmodifiable([
          for (var slotIndex = 0; slotIndex < reportPhotosPerBlock; slotIndex++)
            PhotoSlotSpec(
              slotNumber: blockIndex * reportPhotosPerBlock + slotIndex + 1,
              photo:
                  blockIndex * reportPhotosPerBlock + slotIndex < photos.length
                  ? photos[blockIndex * reportPhotosPerBlock + slotIndex]
                  : null,
            ),
        ]),
      ),
  ]);
}

class ReportPage {
  const ReportPage({
    required this.kind,
    this.item,
    this.photoBlock,
    this.showItemHeader = false,
  }) : assert(kind != ReportPageKind.cover || item == null),
       assert(kind != ReportPageKind.item || item != null),
       assert(photoBlock == null || kind == ReportPageKind.item);

  final ReportPageKind kind;
  final ReportItemSpec? item;
  final PhotoBlockSpec? photoBlock;
  final bool showItemHeader;

  bool get isCover => kind == ReportPageKind.cover;
  bool get hasPhotoBlock => photoBlock != null;
  String? get photoBlockHeader => photoBlock?.label;
  List<PhotoSlotSpec> get photoSlots =>
      photoBlock?.slots ?? const <PhotoSlotSpec>[];
}

class ReportHeaderSpec {
  const ReportHeaderSpec({
    required this.siteName,
    required this.inspectionDate,
    required this.asr,
  });

  final String siteName;
  final String inspectionDate;
  final String asr;
}

class ReportCoverSpec {
  const ReportCoverSpec({
    required this.siteName,
    required this.asr,
    required this.preparedFor,
    required this.address,
    required this.inspectionDate,
  });

  final String siteName;
  final String asr;
  final String preparedFor;
  final String address;
  final String inspectionDate;

  bool get hasAddress => address.isNotEmpty;
}

class ReportContractorSpec {
  const ReportContractorSpec({
    required this.name,
    required this.address,
    required this.cityStateZip,
  });

  final String name;
  final String address;
  final String cityStateZip;
}

class ReportItemSpec {
  const ReportItemSpec({
    required this.sectionId,
    required this.sectionTitle,
    required this.showSectionHeader,
    required this.itemId,
    required this.title,
    required this.fullLabel,
    required this.status,
    required this.observation,
    required this.photoBlocks,
  });

  final String sectionId;
  final String sectionTitle;
  final bool showSectionHeader;
  final String itemId;
  final String title;
  final String fullLabel;
  final StatusRowSpec status;
  final ObservationBlockSpec? observation;
  final List<PhotoBlockSpec> photoBlocks;

  bool get photosEnabled => photoBlocks.isNotEmpty;
  bool get hasObservationBlock => observation != null;
}

class StatusRowSpec {
  const StatusRowSpec({required this.cells});

  factory StatusRowSpec.fromStatuses(
    List<String> statuses,
    String? selectedStatus,
  ) => StatusRowSpec(
    cells: List.unmodifiable([
      for (final status in statuses)
        StatusCellSpec(label: status, selected: status == selectedStatus),
    ]),
  );

  final List<StatusCellSpec> cells;

  String? get selectedStatus {
    for (final cell in cells) {
      if (cell.selected) return cell.label;
    }
    return null;
  }
}

class StatusCellSpec {
  const StatusCellSpec({required this.label, required this.selected});

  final String label;
  final bool selected;
}

class ObservationBlockSpec {
  const ObservationBlockSpec({
    this.title = 'Observations and Recommendations',
    required this.comments,
    this.maxLines = 20,
    this.overflow = ReportTextOverflow.preserve,
  });

  final String title;
  final String comments;
  final int maxLines;
  final ReportTextOverflow overflow;
}

class PhotoBlockSpec {
  const PhotoBlockSpec({
    required this.blockNumber,
    required this.label,
    required this.continued,
    required this.slots,
  });

  final int blockNumber;
  final String label;
  final bool continued;
  final List<PhotoSlotSpec> slots;

  int get emptySlotCount => slots.where((slot) => slot.isEmpty).length;
}

class PhotoSlotSpec {
  const PhotoSlotSpec({required this.slotNumber, required this.photo});

  final int slotNumber;
  final PhotoAttachment? photo;

  bool get isEmpty => photo == null;
  String? get reportPath => photo?.reportPath;
}
