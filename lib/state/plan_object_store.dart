// The plan workspace's object store (ADR-0037 P2).
//
// Three shapes are borrowed from Anytype on purpose, and each has a test:
//
// 1. Content lives in one map of records; a collection holds ids, not copies
//    (`ObjectStore` + `DataViewState.Loaded(objects: ids)` — the row is
//    resolved per-record at render time, `sets/ObjectSetDatabase.kt:24`).
// 2. Subscriptions are refcounted per collection
//    (`domain/objects/ObjectStore.kt:50-60`), so opening a second viewer on
//    the same set does not duplicate state, and closing the last one releases.
// 3. Every mutation bumps one monotonic `revision` — upstream's reason for
//    doing the same (`DataViewSubscriptionContainer.kt:96`) is that a
//    de-duplicating listener can swallow a render; the salt is what stops that.
//
// Everything else is the same discipline the settings store already uses:
// atomic tmp+rename, a corrupt file reads as empty, `lib/state` never imports
// `lib/ui`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../model/plan_block.dart';
import '../model/plan_dataview.dart';
import '../model/plan_filter_engine.dart';
import '../model/plan_object_type.dart';
import '../model/plan_relation.dart';
import '../model/plan_space.dart';
import '../model/plan_struct.dart';
import '../model/plan_template.dart';
import '../model/plan_widget.dart';

/// The struct key that carries per-record restrictions. Upstream gets the same
/// numbers from the middleware; the mock writes them into the record.
const planRestrictionsKey = 'restrictions';

/// A snapshot of one collection's viewer: the ordered ids a surface draws.
class PlanViewerStage {
  const PlanViewerStage({
    required this.collection,
    required this.viewer,
    required this.ids,
    required this.groups,
    required this.revision,
    required this.records,
    this.advancedFilterCount = 0,
  });

  final PlanCollection collection;
  final PlanViewer? viewer;

  /// Flat order for the three list-ish viewers.
  final List<String> ids;

  /// Column buckets for the board; empty for every other kind.
  final Map<String, List<String>> groups;

  /// The store's monotonic revision at the moment this stage was computed.
  final int revision;

  /// Records for [ids], resolved in order — the missing ones are records that
  /// were deleted between a notification and a rebuild.
  final List<PlanObject> records;

  /// How many filter rows this client cannot evaluate (nested/advanced).
  final int advancedFilterCount;

  bool get isUnsupported => viewer != null && !viewer!.kind.renderedByClient;

  /// An unsupported viewer must still be a legal state, not an empty one: the
  /// surface asks this before it draws anything.
  String? get unsupportedReasonKey => viewer?.kind.unsupportedL10nKey;
}

class PlanObjectStore extends ChangeNotifier {
  PlanObjectStore._({
    required File file,
    required Map<String, PlanObject> objects,
    required List<PlanCollection> collections,
    required List<PlanObjectType> types,
    required List<PlanRelation> relations,
    required List<PlanTemplate> templates,
    required List<PlanWidget> widgets,
    required Set<String> bin,
    required this.revision,
  }) : _file = file,
       _objects = objects,
       _collections = collections,
       _types = types,
       _relations = relations,
       _templates = templates,
       _widgets = widgets,
       _bin = bin;

  static const _fileName = 'plan_space.json';

  /// Open the space from Application Support, seeding it with [seed] when the
  /// file is missing. A corrupt file reads as empty rather than throwing the
  /// workspace back to a hero picker.
  static Future<PlanObjectStore> open(
    Directory root, {
    PlanSpaceSeed? seed,
  }) async {
    final file = File('${root.path}/$_fileName');
    if (file.existsSync()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?>) {
          return PlanObjectStore._read(
            file: file,
            json: decoded,
            fallback: seed,
          );
        }
      } on FormatException {
        // Not JSON: fall through to the seed.
      } on FileSystemException {
        // Unreadable: same.
      }
    }
    final seedSpace = seed ?? PlanSpaceSeed.empty;
    return PlanObjectStore._(
      file: file,
      objects: {for (final o in seedSpace.objects) o.id: o},
      collections: [...seedSpace.collections],
      types: [...seedSpace.types],
      relations: [...seedSpace.relations],
      templates: [...seedSpace.templates],
      widgets: [...seedSpace.widgets],
      bin: {...seedSpace.bin},
      revision: 0,
    );
  }

  static PlanObjectStore _read({
    required File file,
    required Map<String, Object?> json,
    required PlanSpaceSeed? fallback,
  }) {
    List<T> list<T>(
      String key,
      T Function(Map<String, Object?>) decode,
      List<T> whenAbsent,
    ) {
      final raw = json[key];
      if (raw is! List) return whenAbsent;
      return [
        for (final entry in raw)
          if (entry is Map<String, Object?>) decode(entry),
      ];
    }

    final objects = list('objects', PlanObject.fromJson, const []);
    return PlanObjectStore._(
      file: file,
      objects: {for (final object in objects) object.id: object},
      collections: list('collections', PlanCollection.fromJson, const []),
      types: list('types', PlanObjectType.fromJson, const []),
      relations: list('relations', PlanRelation.fromJson, const []),
      templates: list('templates', PlanTemplate.fromJson, const []),
      widgets: list('widgets', PlanWidget.fromJson, const []),
      bin: {
        for (final id in (json['bin'] as List<Object?>? ?? const []))
          if (id is String) id,
      },
      revision: (json['revision'] as num?)?.toInt() ?? 0,
    );
  }

  final File _file;

  Map<String, PlanObject> _objects;
  List<PlanCollection> _collections;
  List<PlanObjectType> _types;
  List<PlanRelation> _relations;
  List<PlanTemplate> _templates;
  List<PlanWidget> _widgets;
  Set<String> _bin;

  /// Monotonic; one step per mutation. A surface that caches a stage compares
  /// this, not the id list, to decide whether to rebuild.
  int revision;

  final Map<String, int> _subscriptions = {};
  int _idCounter = 0;

  String _newId(String prefix) =>
      '$prefix${++_idCounter}-${DateTime.now().microsecondsSinceEpoch}';

  // ---- reads --------------------------------------------------------------

  List<PlanObject> get objects => List.unmodifiable(_objects.values);
  List<PlanCollection> get collections => List.unmodifiable(_collections);
  List<PlanObjectType> get types => List.unmodifiable(_types);
  List<PlanRelation> get relations => List.unmodifiable(_relations);
  List<PlanTemplate> get templates => List.unmodifiable(_templates);
  List<PlanWidget> get widgets => List.unmodifiable(orderPlanWidgets(_widgets));
  Set<String> get binIds => Set.unmodifiable(_bin);
  int subscriptionsFor(String collectionId) =>
      _subscriptions[collectionId] ?? 0;

  PlanObject? byId(String id) => _objects[id];

  PlanCollection? collectionById(String id) {
    for (final collection in _collections) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  PlanObjectType? typeByKey(String uniqueKey) {
    for (final type in _types) {
      if (type.uniqueKey == uniqueKey) return type;
    }
    return null;
  }

  PlanRelation? relationByKey(String key) {
    for (final relation in _relations) {
      if (relation.key == key) return relation;
    }
    return null;
  }

  Map<String, PlanRelation> get relationsByKey => {
    for (final relation in _relations) relation.key: relation,
  };

  Set<PlanObjectRestriction> restrictionsFor(PlanObject object) =>
      PlanObjectRestriction.codesToSet([
        for (final code
            in (object.relation(planRestrictionsKey) as List<Object?>? ??
                const []))
          if (code is num) code.toInt(),
      ]);

  // ---- stage: the viewer's answer -----------------------------------------

  /// Compute what a viewer shows. Filters, sorts, grouping and the manual
  /// order all run through the engine, so there is exactly one answer per
  /// (collection, viewer) pair — including for the two kinds the client does
  /// not draw, which return an empty stage with the unsupported reason set.
  PlanViewerStage stageFor(String collectionId, {String? viewerId}) {
    final collection = collectionById(collectionId);
    if (collection == null) {
      return PlanViewerStage(
        collection: PlanCollection(
          id: collectionId,
          name: '',
          kind: PlanCollectionKind.collection,
        ),
        viewer: null,
        ids: const [],
        groups: const {},
        revision: revision,
        records: const [],
      );
    }
    final viewer = viewerId == null
        ? collection.activeViewer
        : collection.dataView.viewerById(viewerId);

    if (viewer == null || !viewer.kind.renderedByClient) {
      return PlanViewerStage(
        collection: collection,
        viewer: viewer,
        ids: const [],
        groups: const {},
        revision: revision,
        records: const [],
        advancedFilterCount: viewer == null
            ? 0
            : splitAdvanced(viewer.filters).length,
      );
    }

    final relations = relationsByKey;
    final candidates = collection
        .candidateRecordIds(_objects.values)
        .where(_objects.containsKey)
        .toList();
    final ids = selectPlanRecordIds(
      candidateIds: candidates,
      objects: _objects,
      relations: relations,
      filters: viewer.filters,
      sorts: viewer.sorts,
      membership: collection.kind == PlanCollectionKind.collection
          ? collection.members
          : const [],
      manualOrder: collection.dataView.objectOrders[viewer.id] ?? const [],
    );

    final group = viewer.groupRelationKey;
    final groups = group == null
        ? const <String, List<String>>{}
        : groupPlanRecordIds(
            ids: ids,
            objects: _objects,
            groupRelationKey: group,
            relation: relations[group],
            optionOrder:
                collection.dataView.groupOrders[viewer.id] ??
                (relations[group]?.optionOrderIds ?? const []),
          );

    final drawn = groups.isEmpty
        ? ids
        : [for (final list in groups.values) ...list];
    return PlanViewerStage(
      collection: collection,
      viewer: viewer,
      ids: drawn,
      groups: groups,
      revision: revision,
      records: [
        for (final id in drawn)
          if (_objects[id] != null) _objects[id]!,
      ],
      advancedFilterCount: splitAdvanced(viewer.filters).length,
    );
  }

  // ---- record writes ------------------------------------------------------

  Future<PlanObject> createRecord({
    required String collectionId,
    String? typeKey,
    Map<String, Object?> values = const {},
    String? templateId,
  }) async {
    final type = typeKey ?? PlanObjectTypeIds.page;
    final template = templateId == null ? null : _templateById(templateId);
    // Recommended fields seed the record the way the type says they should;
    // a null template is "blank", never an error (`ApplyTemplate.kt:26-30`).
    final recommended = typeByKey(type)?.recommendedRelationKeys ?? const [];
    final struct = <String, Object?>{
      PlanRelationKeys.type: type,
      for (final key in recommended)
        if (relationByKey(key)?.format case final PlanRelationFormat format)
          key: format == PlanRelationFormat.checkbox ? false : null,
      ...values,
      if (template != null) 'templateId': template.id,
    }..removeWhere((_, value) => value == null);

    final record = PlanObject(id: _newId('r'), struct: struct);
    _objects = {..._objects, record.id: record};
    if (collectionById(collectionId) case final collection?) {
      _collections = [
        for (final other in _collections)
          if (other.id == collection.id)
            other.copyWith(
              members: collection.kind == PlanCollectionKind.collection
                  ? [...collection.members, record.id]
                  : collection.members,
            )
          else
            other,
      ];
    }
    await _commit();
    return record;
  }

  Future<void> amendRecord(String id, Map<String, Object?> changes) async {
    final object = _objects[id];
    if (object == null) return;
    final normalized = <String, Object?>{};
    changes.forEach((key, value) {
      final relation = relationByKey(key);
      normalized[key] = relation?.normalizeValue(value) ?? value;
    });
    _objects = {..._objects, id: object.amend(normalized)};
    await _commit();
  }

  Future<void> unsetRecord(String id, List<String> keys) async {
    final object = _objects[id];
    if (object == null) return;
    _objects = {..._objects, id: object.unset(keys)};
    await _commit();
  }

  Future<void> toggleRecord(String id) async {
    final object = _objects[id];
    if (object == null) return;
    _objects = {
      ..._objects,
      id: object.amend({PlanRelationKeys.done: !object.isDone}),
    };
    await _commit();
  }

  /// Move to the bin: the record keeps existing, `isArchived` is set, and the
  /// bin widget is the only surface that lists it (upstream has no bin screen).
  Future<void> archiveRecords(List<String> ids) async {
    _bin = {..._bin, ...ids};
    for (final id in ids) {
      final object = _objects[id];
      if (object != null) {
        _objects = {
          ..._objects,
          id: object.amend({'isArchived': true}),
        };
      }
    }
    await _commit();
  }

  Future<void> restoreRecords(List<String> ids) async {
    _bin = _bin.difference(ids.toSet());
    for (final id in ids) {
      final object = _objects[id];
      if (object != null) {
        _objects = {
          ..._objects,
          id: object.unset(['isArchived']),
        };
      }
    }
    await _commit();
  }

  Future<void> emptyBin() async {
    for (final id in _bin) {
      _objects = {..._objects}..remove(id);
    }
    _bin = {};
    await _commit();
  }

  // ---- viewer writes ------------------------------------------------------

  /// The one path that changes a collection's data view. Every viewer edit
  /// goes through it, so a new `PlanDataView` field has one place to be added.
  Future<void> _patchView(
    String collectionId,
    PlanDataView Function(PlanDataView) transform,
  ) async {
    _collections = [
      for (final other in _collections)
        if (other.id == collectionId)
          other.copyWith(dataView: transform(other.dataView))
        else
          other,
    ];
    await _commit();
  }

  Future<void> _writeViewer(
    String collectionId,
    String viewerId,
    PlanViewer Function(PlanViewer) transform,
  ) => _patchView(
    collectionId,
    (view) => _replaceViewer(view, viewerId, transform),
  );

  Future<void> setViewerFilters(
    String collectionId,
    String viewerId,
    List<PlanFilter> filters,
  ) => _writeViewer(
    collectionId,
    viewerId,
    (viewer) => viewer.copyWith(filters: filters),
  );

  Future<void> setViewerSorts(
    String collectionId,
    String viewerId,
    List<PlanSort> sorts,
  ) => _writeViewer(
    collectionId,
    viewerId,
    (viewer) => viewer.copyWith(sorts: sorts),
  );

  Future<void> setViewerRelations(
    String collectionId,
    String viewerId,
    List<PlanViewerRelation> relations,
  ) => _writeViewer(
    collectionId,
    viewerId,
    (viewer) => viewer.copyWith(relations: relations),
  );

  Future<void> setViewerLayout(
    String collectionId,
    String viewerId, {
    PlanViewerSize? cardSize,
    bool? coverFit,
    String? coverRelationKey,
    String? groupRelationKey,
    bool? hideIcon,
    String? defaultObjectTypeId,
    String? defaultTemplateId,
  }) => _writeViewer(
    collectionId,
    viewerId,
    (viewer) => viewer.copyWith(
      cardSize: cardSize,
      coverFit: coverFit,
      coverRelationKey: coverRelationKey ?? viewer.coverRelationKey,
      groupRelationKey: groupRelationKey ?? viewer.groupRelationKey,
      hideIcon: hideIcon,
      defaultObjectTypeId: defaultObjectTypeId ?? viewer.defaultObjectTypeId,
      defaultTemplateId: defaultTemplateId ?? viewer.defaultTemplateId,
    ),
  );

  Future<void> renameViewer(
    String collectionId,
    String viewerId,
    String name,
  ) => _writeViewer(
    collectionId,
    viewerId,
    (viewer) => viewer.copyWith(name: name),
  );

  Future<void> setActiveViewer(String collectionId, String viewerId) =>
      _patchView(
        collectionId,
        (view) => view.copyWith(activeViewerId: viewerId),
      );

  /// A new viewer starts with every relation as a column and the featured ones
  /// visible — the same default upstream gives a fresh Grid.
  Future<void> addViewer(String collectionId, PlanViewerKind kind) async {
    if (collectionById(collectionId) == null) return;
    final viewer = PlanViewer(
      id: _newId('v'),
      name: 'New ${kind.formattedName}',
      kind: kind,
      relations: [
        for (final relation in _relations)
          PlanViewerRelation(key: relation.key, isVisible: relation.featured),
      ],
      groupRelationKey: kind == PlanViewerKind.board
          ? PlanRelationKeys.status
          : null,
    );
    await _patchView(
      collectionId,
      (view) => view.copyWith(
        viewers: [...view.viewers, viewer],
        activeViewerId: viewer.id,
      ),
    );
  }

  /// Upstream's `duplicate`: the copy lands right after the original.
  Future<void> duplicateViewer(String collectionId, String viewerId) async {
    final source = collectionById(collectionId)?.dataView.viewerById(viewerId);
    if (source == null) return;
    final copy = PlanViewer(
      id: _newId('v'),
      name: '${source.name} (1)',
      kind: source.kind,
      relations: source.relations,
      filters: source.filters,
      sorts: source.sorts,
      cardSize: source.cardSize,
      coverFit: source.coverFit,
      coverRelationKey: source.coverRelationKey,
      groupRelationKey: source.groupRelationKey,
      groupBackgroundColors: source.groupBackgroundColors,
      hideIcon: source.hideIcon,
      defaultTemplateId: source.defaultTemplateId,
      defaultObjectTypeId: source.defaultObjectTypeId,
    );
    await _patchView(collectionId, (view) {
      final viewers = [...view.viewers];
      viewers.insert(viewers.indexWhere((v) => v.id == viewerId) + 1, copy);
      return view.copyWith(viewers: viewers);
    });
  }

  /// The last viewer cannot be deleted: an empty tab strip is not a state a
  /// collection can be shown in.
  Future<void> removeViewer(String collectionId, String viewerId) async {
    final view = collectionById(collectionId)?.dataView;
    if (view == null || view.viewers.length < 2) return;
    final remaining = [
      for (final viewer in view.viewers)
        if (viewer.id != viewerId) viewer,
    ];
    await _patchView(
      collectionId,
      (current) => current.copyWith(
        viewers: remaining,
        activeViewerId: current.activeViewerId == viewerId
            ? remaining.first.id
            : current.activeViewerId,
        objectOrders: {...current.objectOrders}..remove(viewerId),
        groupOrders: {...current.groupOrders}..remove(viewerId),
      ),
    );
  }

  Future<void> moveViewer(String collectionId, int from, int to) async {
    final viewers = <PlanViewer>[
      ...?collectionById(collectionId)?.dataView.viewers,
    ];
    if (viewers.isEmpty || from < 0 || from >= viewers.length) return;
    viewers.insert(to.clamp(0, viewers.length - 1), viewers.removeAt(from));
    await _patchView(collectionId, (view) => view.copyWith(viewers: viewers));
  }

  /// Manual order for one viewer — the `custom` sort's stored answer.
  Future<void> setManualOrder(
    String collectionId,
    String viewerId,
    List<String> ids,
  ) => _patchView(
    collectionId,
    (view) =>
        view.copyWith(objectOrders: {...view.objectOrders, viewerId: ids}),
  );

  Future<void> setGroupOrder(
    String collectionId,
    String viewerId,
    List<String> optionIds,
  ) => _patchView(
    collectionId,
    (view) =>
        view.copyWith(groupOrders: {...view.groupOrders, viewerId: optionIds}),
  );

  /// A board drag changes the record's group relation, then the target
  /// column's order. Everything else keeps its place.
  Future<void> moveWithinBoard({
    required String collectionId,
    required String viewerId,
    required String recordId,
    required String toOptionId,
    required int toIndex,
  }) async {
    final group = collectionById(
      collectionId,
    )?.dataView.viewerById(viewerId)?.groupRelationKey;
    if (group == null) return;
    if (toOptionId.isEmpty) {
      await unsetRecord(recordId, [group]);
    } else {
      await amendRecord(recordId, {group: toOptionId});
    }
    final stage = stageFor(collectionId, viewerId: viewerId);
    final column = [
      for (final id in stage.groups[toOptionId] ?? const <String>[])
        if (id != recordId) id,
    ];
    column.insert(toIndex.clamp(0, column.length), recordId);
    final ordered = <String>[
      for (final entry in stage.groups.entries)
        if (entry.key != toOptionId) ...entry.value,
      ...column,
    ];
    await setManualOrder(collectionId, viewerId, ordered);
  }

  // ---- collection membership ----------------------------------------------

  Future<void> addRecordsToCollection(
    String collectionId,
    List<String> ids,
  ) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    _collections = [
      for (final other in _collections)
        if (other.id == collectionId)
          other.copyWith(
            members: [
              ...other.members,
              ...ids.where((id) => !other.members.contains(id)),
            ],
          )
        else
          other,
    ];
    await _commit();
  }

  Future<void> removeRecordFromCollection(
    String collectionId,
    String recordId,
  ) async {
    final collection = collectionById(collectionId);
    if (collection == null) return;
    _collections = [
      for (final other in _collections)
        if (other.id == collectionId)
          other.copyWith(
            members: [
              for (final id in other.members)
                if (id != recordId) id,
            ],
          )
        else
          other,
    ];
    await _commit();
  }

  // ---- relations ----------------------------------------------------------

  /// Enforces upstream's gate: the sheet offers eleven formats and no more
  /// (`feature-properties/.../UiEditTypePropertiesState.kt:20-32`).
  Future<PlanRelation?> createRelation({
    required String key,
    required String name,
    required PlanRelationFormat format,
  }) async {
    if (!PlanRelationFormat.creatable.contains(format)) return null;
    if (relationByKey(key) != null) return null;
    final relation = PlanRelation(
      id: _newId('rel'),
      key: key,
      name: name,
      format: format,
    );
    _relations = [..._relations, relation];
    await _commit();
    return relation;
  }

  Future<void> renameRelation(String key, String name) async {
    final relation = relationByKey(key);
    if (relation == null) return;
    _relations = [
      for (final other in _relations)
        if (other.key == key) other.copyWith(name: name) else other,
    ];
    await _commit();
  }

  Future<void> setRelationFeatured(String key, {required bool featured}) async {
    final relation = relationByKey(key);
    if (relation == null) return;
    _relations = [
      for (final other in _relations)
        if (other.key == key) other.copyWith(featured: featured) else other,
    ];
    await _commit();
  }

  Future<void> setRelationHidden(String key, {required bool hidden}) async {
    final relation = relationByKey(key);
    if (relation == null) return;
    _relations = [
      for (final other in _relations)
        if (other.key == key) other.copyWith(hidden: hidden) else other,
    ];
    await _commit();
  }

  Future<void> addRelationOption(String key, PlanRelationOption option) async {
    final relation = relationByKey(key);
    if (relation == null || !relation.format.hasOptions) return;
    _relations = [
      for (final other in _relations)
        if (other.key == key)
          other.copyWith(options: [...other.options, option])
        else
          other,
    ];
    await _commit();
  }

  Future<void> deleteRelationOptions(String key, List<String> optionIds) async {
    final relation = relationByKey(key);
    if (relation == null) return;
    final removed = optionIds.toSet();
    _relations = [
      for (final other in _relations)
        if (other.key == key)
          other.copyWith(
            options: [
              for (final option in other.options)
                if (!removed.contains(option.id)) option,
            ],
          )
        else
          other,
    ];
    // Anytype also clears the value from every record that held it.
    for (final entry in _objects.entries) {
      final value = entry.value.relation(key);
      if (value == null) continue;
      final kept = [
        for (final item in _asIdList(value))
          if (!removed.contains(item)) item,
      ];
      _objects = {
        ..._objects,
        entry.key: kept.isEmpty
            ? entry.value.unset([key])
            : entry.value.amend({key: kept}),
      };
    }
    await _commit();
  }

  Future<void> setRelationOptionOrder(
    String key,
    List<String> optionIds,
  ) async {
    final relation = relationByKey(key);
    if (relation == null) return;
    final byId = {for (final option in relation.options) option.id: option};
    _relations = [
      for (final other in _relations)
        if (other.key == key)
          other.copyWith(
            options: [
              for (final id in optionIds)
                if (byId[id] != null) byId[id]!,
            ],
          )
        else
          other,
    ];
    await _commit();
  }

  // ---- types --------------------------------------------------------------

  Future<PlanObjectType> createType({
    required String name,
    String iconEmoji = '',
    List<String> recommendedRelationKeys = const [],
  }) async {
    final type = PlanObjectType(
      id: _newId('t'),
      uniqueKey: 'ot-${_newId('k')}',
      name: name,
      iconEmoji: iconEmoji.isEmpty ? null : iconEmoji,
      recommendedRelationKeys: recommendedRelationKeys,
    );
    _types = [..._types, type];
    await _commit();
    return type;
  }

  Future<void> updateType(PlanObjectType type) async {
    _types = [
      for (final other in _types)
        if (other.id == type.id) type else other,
    ];
    await _commit();
  }

  Future<void> pinType(String typeId, {required bool pinned}) =>
      _patchType(typeId, (type) => type.copyWith(pinned: pinned));

  /// "Move to bin" for a type: archived types leave the list but their records
  /// keep the key, exactly as upstream's `isArchived` does.
  Future<void> archiveType(String typeId, {required bool archived}) =>
      _patchType(typeId, (type) => type.copyWith(isArchived: archived));

  Future<void> _patchType(
    String typeId,
    PlanObjectType Function(PlanObjectType) transform,
  ) async {
    _types = [
      for (final other in _types)
        if (other.id == typeId) transform(other) else other,
    ];
    await _commit();
  }

  Future<void> setDefaultType(String typeId) async {
    _types = [
      for (final other in _types)
        other.copyWith(defaultType: other.id == typeId),
    ];
    await _commit();
  }

  // ---- templates ----------------------------------------------------------

  PlanTemplate? _templateById(String id) {
    for (final template in _templates) {
      if (template.id == id) return template;
    }
    return null;
  }

  Future<PlanTemplate?> createTemplate({
    required String name,
    required String typeKey,
    List<PlanBlock> blocks = const [],
  }) async {
    if (!PlanObjectTypeIds.allowsTemplates(typeKey)) return null;
    final template = PlanTemplate(
      id: _newId('tpl'),
      name: name,
      typeKey: typeKey,
      blocks: blocks,
    );
    _templates = [..._templates, template];
    await _commit();
    return template;
  }

  Future<void> deleteTemplate(String id) async {
    _templates = [
      for (final template in _templates)
        if (template.id != id) template,
    ];
    await _commit();
  }

  Future<void> setDefaultTemplate(String typeKey, String? templateId) async {
    _templates = [
      for (final template in _templates)
        if (template.typeKey == typeKey)
          template.copyWith(isDefault: template.id == templateId)
        else
          template,
    ];
    _types = [
      for (final type in _types)
        if (type.uniqueKey == typeKey)
          type.copyWith(defaultTemplateId: templateId)
        else
          type,
    ];
    await _commit();
  }

  // ---- widgets ------------------------------------------------------------

  Future<void> addWidget({
    required PlanWidgetSource source,
    PlanWidgetLayout layout = PlanWidgetLayout.list,
    PlanWidgetSection section = PlanWidgetSection.pinned,
    int? limit,
  }) async {
    final widget = PlanWidget(
      id: _newId('w'),
      source: source,
      layout: layout,
      section: section,
      limit: limit,
    );
    _widgets = [..._widgets, widget];
    await _commit();
  }

  Future<void> changeWidgetLayout(String widgetId, PlanWidgetLayout layout) =>
      _patchWidget(widgetId, (widget) => widget.copyWith(layout: layout));

  Future<void> setWidgetLimit(String widgetId, int limit) =>
      _patchWidget(widgetId, (widget) => widget.copyWith(limit: limit));

  Future<void> setWidgetActiveView(String widgetId, String? viewerId) =>
      _patchWidget(
        widgetId,
        (widget) => widget.copyWith(activeViewId: viewerId),
      );

  Future<void> removeWidget(String widgetId) async {
    _widgets = [
      for (final widget in _widgets)
        if (widget.id != widgetId) widget,
    ];
    await _commit();
  }

  Future<void> reorderWidgets(int from, int to) async {
    final ordered = orderPlanWidgets(_widgets);
    if (from < 0 || from >= ordered.length) return;
    to = to.clamp(0, ordered.length - 1);
    ordered.insert(to, ordered.removeAt(from));
    _widgets = ordered;
    await _commit();
  }

  Future<void> _patchWidget(
    String widgetId,
    PlanWidget Function(PlanWidget) transform,
  ) async {
    _widgets = [
      for (final widget in _widgets)
        if (widget.id == widgetId) transform(widget) else widget,
    ];
    await _commit();
  }

  // ---- favourites ---------------------------------------------------------

  Future<void> setFavorite(String recordId, {required bool favorite}) async {
    final record = _objects[recordId];
    if (record == null) return;
    await amendRecord(recordId, {'isFavorite': favorite});
  }

  List<PlanObject> get favorites => [
    for (final object in _objects.values)
      if (object.relation('isFavorite') == true && !_bin.contains(object.id))
        object,
  ];

  List<PlanObject> get recentlyEdited =>
      [
        for (final object in _objects.values)
          if (object.relation('editedAt') != null && !_bin.contains(object.id))
            object,
      ]..sort(
        (a, b) => (b.relation('editedAt') as String).compareTo(
          a.relation('editedAt') as String,
        ),
      );

  List<PlanObject> get binRecords => [
    for (final object in _objects.values)
      if (_bin.contains(object.id)) object,
  ];

  /// All records of one type — `All Content`'s tab answer.
  List<PlanObject> recordsOfType(String typeKey) => [
    for (final object in _objects.values)
      if (object.typeKey == typeKey && !_bin.contains(object.id)) object,
  ];

  List<PlanObject> get unlinkedRecords => [
    for (final object in _objects.values)
      if (object.options(PlanRelationKeys.links).isEmpty &&
          !_bin.contains(object.id))
        object,
  ];

  // ---- subscriptions ------------------------------------------------------

  /// Attach a viewer to a collection. Returns the token to release with.
  String subscribe(String collectionId) {
    final token = '$collectionId#${_newId('sub')}';
    _subscriptions[collectionId] = (_subscriptions[collectionId] ?? 0) + 1;
    return token;
  }

  void unsubscribe(String collectionId) {
    final count = (_subscriptions[collectionId] ?? 0) - 1;
    if (count <= 0) {
      _subscriptions.remove(collectionId);
    } else {
      _subscriptions[collectionId] = count;
    }
  }

  // ---- commit -------------------------------------------------------------

  Future<void> _commit() async {
    revision++;
    await _save();
    notifyListeners();
  }

  Future<void> _save() async {
    final temp = File('${_file.path}.tmp');
    await temp.parent.create(recursive: true);
    await temp.writeAsString(
      jsonEncode({
        'revision': revision,
        'objects': [
          for (final id in _objects.keys.toList()..sort())
            _objects[id]!.toJson(),
        ],
        'collections': [for (final c in _collections) c.toJson()],
        'types': [for (final t in _types) t.toJson()],
        'relations': [for (final r in _relations) r.toJson()],
        'templates': [for (final t in _templates) t.toJson()],
        'widgets': [for (final w in _widgets) w.toJson()],
        'bin': [..._bin]..sort(),
      }),
      flush: true,
    );
    await temp.rename(_file.path);
  }

  List<String> _asIdList(Object? value) => switch (value) {
    final String single => [single],
    final List<Object?> list => [
      for (final entry in list)
        if (entry != null) entry.toString(),
    ],
    _ => const [],
  };
}

PlanDataView _replaceViewer(
  PlanDataView view,
  String viewerId,
  PlanViewer Function(PlanViewer) transform,
) {
  return PlanDataView(
    viewers: [
      for (final viewer in view.viewers)
        viewer.id == viewerId ? transform(viewer) : viewer,
    ],
    activeViewerId: view.activeViewerId,
    objectOrders: view.objectOrders,
    groupOrders: view.groupOrders,
  );
}
