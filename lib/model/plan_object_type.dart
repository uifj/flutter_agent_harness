// Object types (ADR-0037 §4). The 21 bundled keys are Anytype's
// `ObjectTypeIds` (`core-models/.../ObjectTypeIds.kt:9-31`) and the four
// groupings are its functions at `:35-52`; the `_ot` mirror is the marketplace
// namespace at `:55-76`, and `_anytype_marketplace` the space id at `:79-82`.
//
// Two things this file deliberately does NOT do: invent a `goal`/`habit` type
// (the 0.50.4 client has neither — no `ot-goal`/`ot-habit` key exists, only an
// onboarding use-case label), and give Task its own screen (Anytype renders a
// task as a List-view row with a done box, `sets/model/Viewer.kt:126`).

/// The bundled type keys, verbatim from upstream.
abstract final class PlanObjectTypeIds {
  static const page = 'ot-page';
  static const objectType = 'ot-objectType';
  static const relation = 'ot-relation';
  static const template = 'ot-template';
  static const image = 'ot-image';
  static const file = 'ot-file';
  static const video = 'ot-video';
  static const audio = 'ot-audio';
  static const set = 'ot-set';
  static const collection = 'ot-collection';
  static const task = 'ot-task';
  static const date = 'ot-date';
  static const profile = 'ot-profile';
  static const human = 'ot-human';
  static const participant = 'ot-participant';
  static const note = 'ot-note';
  static const workspace = 'ot-space';
  static const dashboard = 'ot-dashboard';
  static const bookmark = 'ot-bookmark';
  static const relationOption = 'ot-relationOption';
  static const chatDerived = 'ot-chatDerived';
  static const chat = 'ot-chat';
  static const project = 'ot-project';

  static const defaultObjectType = page;

  static const all = <String>[
    page,
    objectType,
    relation,
    template,
    image,
    file,
    video,
    audio,
    set,
    collection,
    task,
    date,
    profile,
    human,
    participant,
    note,
    workspace,
    dashboard,
    bookmark,
    relationOption,
    chatDerived,
    chat,
    project,
  ];

  /// `getTypesWithoutTemplates` (`:35`): bookmarks, the four file types and
  /// the two collection types never take a template.
  static const typesWithoutTemplates = <String>[
    bookmark,
    file,
    image,
    video,
    audio,
    set,
    collection,
    objectType,
    template,
    relation,
    relationOption,
    dashboard,
    date,
  ];

  static const fileTypes = <String>[file, image, audio, video];

  static const setTypes = <String>[set, collection];

  static const systemTypes = <String>[
    objectType,
    template,
    relation,
    relationOption,
    dashboard,
    date,
  ];

  /// Types the client gives a distinct treatment to. Anything absent here is
  /// a plain record — Anytype's `ot-project` is exactly that: it exists in
  /// the type sort priority list (`objects/ObjectTypeSortingExtensions.kt:20`)
  /// and nowhere else.
  static const specialCased = <String>{task, bookmark, date, chat, chatDerived};

  /// Type sort priority, Anytype's own head of list; everything else follows
  /// in the order the space reports it.
  static const sortPriority = <String>[page, note, task, bookmark, project];

  static bool allowsTemplates(String key) =>
      !typesWithoutTemplates.contains(key);

  static bool isFileType(String key) => fileTypes.contains(key);

  static bool isSetType(String key) => setTypes.contains(key);

  static bool isSystemType(String key) => systemTypes.contains(key);

  static int priorityOf(String key) {
    final index = sortPriority.indexOf(key);
    return index < 0 ? sortPriority.length : index;
  }
}

/// The marketplace namespace (`MarketplaceObjectTypeIds`, `:55-76`). Kept
/// because a bundled type and its marketplace twin are different ids for the
/// same shape, and the UI must not confuse them.
abstract final class PlanMarketplaceIds {
  static const prefix = '_ot';
  static const marketplaceSpaceId = '_anytype_marketplace';
  static const setMarketplaceId = '_otset';
  static const collectionMarketplaceId = '_otcollection';

  static String marketplaceKey(String bundledKey) => bundledKey.isEmpty
      ? bundledKey
      : '$prefix${bundledKey.replaceFirst('ot-', '')}';
}

/// What a type can be rendered as. Anytype's seven layouts; a data view is
/// only legal on the two collection types.
enum PlanTypeLayout { basic, todo, profile, paging, inventory, book, note }

/// A type the user (or the mock space) defined. Also an object, per D1.
class PlanObjectType {
  const PlanObjectType({
    required this.id,
    required this.uniqueKey,
    required this.name,
    this.iconEmoji,
    this.colorIndex,
    this.layout = PlanTypeLayout.basic,
    this.recommendedRelationKeys = const [],
    this.defaultTemplateId,
    this.defaultType = false,
    this.isArchived = false,
    this.pinned = false,
    this.sourceObject,
  });

  final String id;
  final String uniqueKey;
  final String name;
  final String? iconEmoji;
  final int? colorIndex;
  final PlanTypeLayout layout;

  /// The fields the type pre-fills on a new record — Anytype's
  /// `SetObjectTypeRecommendedFields` (`feature-object-type/.../
  /// ObjectTypeViewModel.kt:1638`). There is no "recommended views" in the
  /// 0.50.4 client, so this model has none either.
  final List<String> recommendedRelationKeys;

  final String? defaultTemplateId;
  final bool defaultType;
  final bool isArchived;
  final bool pinned;

  /// Null for a type the user made; a bundled key for one that ships.
  final String? sourceObject;

  bool get isBuiltIn => PlanObjectTypeIds.all.contains(uniqueKey);

  bool get allowsTemplates => PlanObjectTypeIds.allowsTemplates(uniqueKey);

  /// Whether records of this type open a data view instead of a document —
  /// the set/collection distinction Anytype draws at
  /// `ObjectTypeExtensions.kt:107-130` (they also skip the template picker).
  bool get isDataSet => PlanObjectTypeIds.isSetType(uniqueKey);

  bool get skipsTemplatePicker => isDataSet;

  PlanObjectType copyWith({
    String? name,
    String? iconEmoji,
    int? colorIndex,
    PlanTypeLayout? layout,
    List<String>? recommendedRelationKeys,
    String? defaultTemplateId,
    bool? defaultType,
    bool? isArchived,
    bool? pinned,
  }) => PlanObjectType(
    id: id,
    uniqueKey: uniqueKey,
    name: name ?? this.name,
    iconEmoji: iconEmoji ?? this.iconEmoji,
    colorIndex: colorIndex ?? this.colorIndex,
    layout: layout ?? this.layout,
    recommendedRelationKeys:
        recommendedRelationKeys ?? this.recommendedRelationKeys,
    defaultTemplateId: defaultTemplateId ?? this.defaultTemplateId,
    defaultType: defaultType ?? this.defaultType,
    isArchived: isArchived ?? this.isArchived,
    pinned: pinned ?? this.pinned,
    sourceObject: sourceObject,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'uniqueKey': uniqueKey,
    'name': name,
    if (iconEmoji != null) 'iconEmoji': iconEmoji,
    if (colorIndex != null) 'colorIndex': colorIndex,
    'layout': layout.name,
    'recommendedRelationKeys': recommendedRelationKeys,
    if (defaultTemplateId != null) 'defaultTemplateId': defaultTemplateId,
    if (defaultType) 'defaultType': true,
    if (isArchived) 'isArchived': true,
    if (pinned) 'pinned': true,
    if (sourceObject != null) 'sourceObject': sourceObject,
  };

  static PlanObjectType fromJson(Map<String, Object?> json) => PlanObjectType(
    id: json['id'] as String? ?? '',
    uniqueKey: json['uniqueKey'] as String? ?? PlanObjectTypeIds.page,
    name: json['name'] as String? ?? '',
    iconEmoji: json['iconEmoji'] as String?,
    colorIndex: (json['colorIndex'] as num?)?.toInt(),
    layout: PlanTypeLayout.values.firstWhere(
      (value) => value.name == json['layout'],
      orElse: () => PlanTypeLayout.basic,
    ),
    recommendedRelationKeys: [
      for (final key
          in (json['recommendedRelationKeys'] as List<Object?>? ?? const []))
        if (key is String) key,
    ],
    defaultTemplateId: json['defaultTemplateId'] as String?,
    defaultType: json['defaultType'] == true,
    isArchived: json['isArchived'] == true,
    pinned: json['pinned'] == true,
    sourceObject: json['sourceObject'] as String?,
  );
}
