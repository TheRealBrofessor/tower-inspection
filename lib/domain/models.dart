typedef JsonMap = Map<String, dynamic>;

DateTime _dateTime(Object? value) => DateTime.parse(value! as String);

Map<String, String> _stringMap(Object? value) =>
    (value as Map<String, dynamic>? ?? const <String, dynamic>{}).map(
      (key, item) => MapEntry(key, item?.toString() ?? ''),
    );

class ContractorDetails {
  const ContractorDetails({
    required this.name,
    required this.address,
    required this.cityStateZip,
  });

  factory ContractorDetails.fromJson(JsonMap json) => ContractorDetails(
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '',
    cityStateZip: json['cityStateZip'] as String? ?? '',
  );

  final String name;
  final String address;
  final String cityStateZip;

  JsonMap toJson() => {
    'name': name,
    'address': address,
    'cityStateZip': cityStateZip,
  };
}

class HeaderConvention {
  const HeaderConvention({
    required this.left,
    required this.asrLabel,
    required this.pageLabel,
  });

  factory HeaderConvention.fromJson(JsonMap json) => HeaderConvention(
    left: json['left'] as String? ?? '',
    asrLabel: json['asrLabel'] as String? ?? '',
    pageLabel: json['pageLabel'] as String? ?? '',
  );

  final String left;
  final String asrLabel;
  final String pageLabel;

  JsonMap toJson() => {
    'left': left,
    'asrLabel': asrLabel,
    'pageLabel': pageLabel,
  };
}

class SiteInfoField {
  const SiteInfoField({
    required this.id,
    required this.label,
    this.example,
    this.defaultValue,
    this.numeric = false,
    this.type,
  });

  factory SiteInfoField.fromJson(JsonMap json) => SiteInfoField(
    id: json['id'] as String,
    label: json['label'] as String,
    example: json['example'] as String?,
    defaultValue: (json['defaultValue'] ?? json['default'])?.toString(),
    numeric: json['numeric'] as bool? ?? false,
    type: json['type'] as String?,
  );

  final String id;
  final String label;
  final String? example;
  final String? defaultValue;
  final bool numeric;
  final String? type;

  JsonMap toJson() => {
    'id': id,
    'label': label,
    if (example != null) 'example': example,
    if (defaultValue != null) 'defaultValue': defaultValue,
    if (numeric) 'numeric': numeric,
    if (type != null) 'type': type,
  };
}

class PhotoBlock {
  const PhotoBlock({
    required this.blockId,
    required this.label,
    required this.continued,
  });

  factory PhotoBlock.fromJson(JsonMap json) => PhotoBlock(
    blockId: json['blockId'] as String,
    label: json['label'] as String,
    continued: json['continued'] as bool? ?? false,
  );

  final String blockId;
  final String label;
  final bool continued;

  JsonMap toJson() => {
    'blockId': blockId,
    'label': label,
    'continued': continued,
  };
}

class InspectionItem {
  const InspectionItem({
    required this.id,
    required this.title,
    required this.instruction,
    required this.fullLabel,
    required this.statuses,
    required this.photosEnabled,
    required this.photoBlocks,
    required this.defaultPhotoSlots,
    required this.commentsEnabled,
    required this.prefilledObservation,
  });

  factory InspectionItem.fromJson(JsonMap json) => InspectionItem(
    id: json['id'] as String,
    title: json['title'] as String,
    instruction: json['instruction'] as String,
    fullLabel: json['fullLabel'] as String,
    statuses: (json['statuses'] as List<dynamic>? ?? const [])
        .map((value) => value as String)
        .toList(growable: false),
    photosEnabled: json['photosEnabled'] as bool? ?? false,
    photoBlocks: (json['photoBlocks'] as List<dynamic>? ?? const [])
        .map((value) => PhotoBlock.fromJson(value as JsonMap))
        .toList(growable: false),
    defaultPhotoSlots: json['defaultPhotoSlots'] as int? ?? 0,
    commentsEnabled: json['commentsEnabled'] as bool? ?? true,
    prefilledObservation: json['prefilledObservation'] as String? ?? '',
  );

  final String id;
  final String title;
  final String instruction;
  final String fullLabel;
  final List<String> statuses;
  final bool photosEnabled;
  final List<PhotoBlock> photoBlocks;
  final int defaultPhotoSlots;
  final bool commentsEnabled;
  final String prefilledObservation;

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'instruction': instruction,
    'fullLabel': fullLabel,
    'statuses': statuses,
    'photosEnabled': photosEnabled,
    'photoBlocks': photoBlocks.map((block) => block.toJson()).toList(),
    'defaultPhotoSlots': defaultPhotoSlots,
    'commentsEnabled': commentsEnabled,
    'prefilledObservation': prefilledObservation,
  };
}

class InspectionSection {
  const InspectionSection({
    required this.id,
    required this.title,
    required this.items,
  });

  factory InspectionSection.fromJson(JsonMap json) => InspectionSection(
    id: json['id'] as String,
    title: json['title'] as String,
    items: (json['items'] as List<dynamic>? ?? const [])
        .map((value) => InspectionItem.fromJson(value as JsonMap))
        .toList(growable: false),
  );

  final String id;
  final String title;
  final List<InspectionItem> items;

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class InspectionTemplate {
  const InspectionTemplate({
    required this.templateVersion,
    required this.reportTitle,
    required this.contractor,
    required this.headerConvention,
    required this.siteInfoFields,
    required this.defaultStatuses,
    required this.sections,
  });

  factory InspectionTemplate.fromJson(JsonMap json) => InspectionTemplate(
    templateVersion: json['templateVersion'] as String,
    reportTitle: json['reportTitle'] as String,
    contractor: ContractorDetails.fromJson(json['contractor'] as JsonMap),
    headerConvention: HeaderConvention.fromJson(
      json['headerConvention'] as JsonMap,
    ),
    siteInfoFields: (json['siteInfoFields'] as List<dynamic>? ?? const [])
        .map((value) => SiteInfoField.fromJson(value as JsonMap))
        .toList(growable: false),
    defaultStatuses: (json['defaultStatuses'] as List<dynamic>? ?? const [])
        .map((value) => value as String)
        .toList(growable: false),
    sections: (json['sections'] as List<dynamic>? ?? const [])
        .map((value) => InspectionSection.fromJson(value as JsonMap))
        .toList(growable: false),
  );

  final String templateVersion;
  final String reportTitle;
  final ContractorDetails contractor;
  final HeaderConvention headerConvention;
  final List<SiteInfoField> siteInfoFields;
  final List<String> defaultStatuses;
  final List<InspectionSection> sections;

  List<InspectionItem> get items => [
    for (final section in sections) ...section.items,
  ];

  InspectionItem? itemById(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  JsonMap toJson() => {
    'templateVersion': templateVersion,
    'reportTitle': reportTitle,
    'contractor': contractor.toJson(),
    'headerConvention': headerConvention.toJson(),
    'siteInfoFields': siteInfoFields.map((field) => field.toJson()).toList(),
    'defaultStatuses': defaultStatuses,
    'sections': sections.map((section) => section.toJson()).toList(),
  };
}

class PhotoAttachment {
  const PhotoAttachment({
    required this.id,
    required this.inspectionId,
    required this.itemId,
    required this.orderIndex,
    required this.originalPath,
    required this.reportPath,
    required this.capturedAt,
    this.metadata = const <String, dynamic>{},
  });

  factory PhotoAttachment.fromJson(JsonMap json) => PhotoAttachment(
    id: json['id'] as String,
    inspectionId: json['inspectionId'] as String,
    itemId: json['itemId'] as String,
    orderIndex: json['orderIndex'] as int,
    originalPath: json['originalPath'] as String,
    reportPath: json['reportPath'] as String,
    capturedAt: _dateTime(json['capturedAt']),
    metadata: Map<String, dynamic>.from(
      json['metadata'] as Map<dynamic, dynamic>? ?? const {},
    ),
  );

  final String id;
  final String inspectionId;
  final String itemId;
  final int orderIndex;
  final String originalPath;
  final String reportPath;
  final DateTime capturedAt;
  final JsonMap metadata;

  PhotoAttachment copyWith({int? orderIndex}) => PhotoAttachment(
    id: id,
    inspectionId: inspectionId,
    itemId: itemId,
    orderIndex: orderIndex ?? this.orderIndex,
    originalPath: originalPath,
    reportPath: reportPath,
    capturedAt: capturedAt,
    metadata: metadata,
  );

  JsonMap toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'itemId': itemId,
    'orderIndex': orderIndex,
    'originalPath': originalPath,
    'reportPath': reportPath,
    'capturedAt': capturedAt.toIso8601String(),
    'metadata': metadata,
  };
}

class InspectionItemResponse {
  const InspectionItemResponse({
    required this.inspectionId,
    required this.itemId,
    this.status,
    this.comments = '',
    this.photos = const <PhotoAttachment>[],
  });

  factory InspectionItemResponse.fromJson(JsonMap json) =>
      InspectionItemResponse(
        inspectionId: json['inspectionId'] as String,
        itemId: json['itemId'] as String,
        status: json['status'] as String?,
        comments: json['comments'] as String? ?? '',
        photos: (json['photos'] as List<dynamic>? ?? const [])
            .map((value) => PhotoAttachment.fromJson(value as JsonMap))
            .toList(growable: false),
      );

  final String inspectionId;
  final String itemId;
  final String? status;
  final String comments;
  final List<PhotoAttachment> photos;

  InspectionItemResponse copyWith({
    String? status,
    String? comments,
    List<PhotoAttachment>? photos,
  }) => InspectionItemResponse(
    inspectionId: inspectionId,
    itemId: itemId,
    status: status ?? this.status,
    comments: comments ?? this.comments,
    photos: photos ?? this.photos,
  );

  JsonMap toJson() => {
    'inspectionId': inspectionId,
    'itemId': itemId,
    'status': status,
    'comments': comments,
    'photos': photos.map((photo) => photo.toJson()).toList(),
  };
}

class Inspection {
  const Inspection({
    required this.id,
    required this.templateVersion,
    required this.siteFields,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.responses = const <InspectionItemResponse>[],
  });

  factory Inspection.fromJson(JsonMap json) => Inspection(
    id: json['id'] as String,
    templateVersion: json['templateVersion'] as String,
    siteFields: _stringMap(json['siteFields']),
    status: json['status'] as String,
    createdAt: _dateTime(json['createdAt']),
    updatedAt: _dateTime(json['updatedAt']),
    responses: (json['responses'] as List<dynamic>? ?? const [])
        .map((value) => InspectionItemResponse.fromJson(value as JsonMap))
        .toList(growable: false),
  );

  static const draftStatus = 'draft';
  static const completedStatus = 'completed';

  final String id;
  final String templateVersion;
  final Map<String, String> siteFields;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<InspectionItemResponse> responses;

  InspectionItemResponse? responseFor(String itemId) {
    for (final response in responses) {
      if (response.itemId == itemId) return response;
    }
    return null;
  }

  Inspection copyWith({
    Map<String, String>? siteFields,
    String? status,
    DateTime? updatedAt,
    List<InspectionItemResponse>? responses,
  }) => Inspection(
    id: id,
    templateVersion: templateVersion,
    siteFields: siteFields ?? this.siteFields,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    responses: responses ?? this.responses,
  );

  JsonMap toJson() => {
    'id': id,
    'templateVersion': templateVersion,
    'siteFields': siteFields,
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'responses': responses.map((response) => response.toJson()).toList(),
  };
}

class Observation {
  const Observation({required this.itemId, required this.text});

  factory Observation.fromJson(JsonMap json) => Observation(
    itemId: json['itemId'] as String,
    text: json['text'] as String? ?? '',
  );

  final String itemId;
  final String text;

  JsonMap toJson() => {'itemId': itemId, 'text': text};
}

class Report {
  const Report({
    required this.id,
    required this.inspectionId,
    required this.filePath,
    required this.createdAt,
    this.observations = const <Observation>[],
    this.metadata = const <String, dynamic>{},
  });

  factory Report.fromJson(JsonMap json) => Report(
    id: json['id'] as String,
    inspectionId: json['inspectionId'] as String,
    filePath: json['filePath'] as String,
    createdAt: _dateTime(json['createdAt']),
    observations: (json['observations'] as List<dynamic>? ?? const [])
        .map((value) => Observation.fromJson(value as JsonMap))
        .toList(growable: false),
    metadata: Map<String, dynamic>.from(
      json['metadata'] as Map<dynamic, dynamic>? ?? const {},
    ),
  );

  final String id;
  final String inspectionId;
  final String filePath;
  final DateTime createdAt;
  final List<Observation> observations;
  final JsonMap metadata;

  JsonMap toJson() => {
    'id': id,
    'inspectionId': inspectionId,
    'filePath': filePath,
    'createdAt': createdAt.toIso8601String(),
    'observations': observations
        .map((observation) => observation.toJson())
        .toList(),
    'metadata': metadata,
  };
}
