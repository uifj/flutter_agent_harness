// The data view's shape (ADR-0037 §1–§2). Values and names are Anytype's
// `Block.Content.DataView` (`core-models/.../Block.kt:268-391`): six viewer
// kinds at `:294-301`, sizes `:303`, per-column options `:306-313`, date and
// time formats `:239-247`, sort types + empty placement `:335-345`, filter
// operators `:366`, the 18 conditions `:367-371`, the 15 date shortcuts
// `:373-377`.
//
// The one thing this file adds is [PlanViewerKind.renderedByClient]. Anytype
// declares six kinds and renders four; CALENDAR and GRAPH resolve to a
// `Viewer.Unsupported` card whose text says "not available on mobile yet"
// (`relations/ObjectSetRenderMapper.kt:188-193`, `sets/model/Viewer.kt:19-30`,
// strings at `localization/.../values/strings.xml:1465-1468`). Encoding the
// answer as data — rather than dropping the two enum values — is what makes
// the reproduction faithful: the kind exists, the client says no, out loud.

import 'plan_struct.dart';

/// The six viewer kinds. Names follow the upstream `formattedName`.
enum PlanViewerKind {
  grid('Grid', true),
  list('List', true),
  gallery('Gallery', true),
  board('Board', true),
  calendar('Calendar', false),
  graph('Graph', false);

  const PlanViewerKind(this.formattedName, this.renderedByClient);

  final String formattedName;

  /// False = the viewer is a supported *kind* the client does not draw, and
  /// the surface must say so instead of silently showing something else.
  final bool renderedByClient;

  /// i18n key for the unsupported card's text; null when the kind renders.
  String? get unsupportedL10nKey => switch (this) {
    calendar => 'planViewCalendarUnsupported',
    graph => 'planViewGraphUnsupported',
    _ => null,
  };

  static PlanViewerKind fromName(String name) =>
      values.firstWhere((value) => value.name == name, orElse: () => grid);
}

/// Why a viewer that *could* render is showing the unsupported card anyway —
/// Anytype's own case: the Kanban gate at `ObjectSetRenderMapper.kt:145-147`.
enum PlanViewerDisabledReason {
  none,
  kanbanDisabled;

  String? l10nKey(PlanViewerKind kind) => switch (this) {
    kanbanDisabled => 'planViewKanbanDisabled',
    none => kind.unsupportedL10nKey,
  };
}

/// `Block.Content.DataView.Viewer.Size`.
enum PlanViewerSize {
  small,
  medium,
  large;

  /// Column width in design pixels at font step 1.0; the surface multiplies
  /// by `MediaQuery.textScalerOf(context).scale(1)` (ADR-0017 S3).
  double get columnWidth => switch (this) {
    small => 120,
    medium => 180,
    large => 260,
  };
}

/// `Block.Content.DataView.DateFormat` (`Block.kt:239-245`).
enum PlanDateFormat {
  monthAbbrBeforeDay,
  monthAbbrAfterDay,
  short,
  medium,
  iso;

  String format(DateTime date) => switch (this) {
    monthAbbrBeforeDay => '${_monthAbbr(date.month)} ${date.day}, ${date.year}',
    monthAbbrAfterDay => '${date.day} ${_monthAbbr(date.month)}, ${date.year}',
    short =>
      '${date.month.toString().padLeft(2, '0')}/'
          '${date.day.toString().padLeft(2, '0')}/${date.year}',
    medium =>
      '${_monthAbbr(date.month)} ${date.day}, '
          '${date.year.toString().substring(2)}',
    iso =>
      '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
  };

  static String _monthAbbr(int month) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][month - 1];
}

/// `Block.Content.DataView.TimeFormat` (`Block.kt:247`).
enum PlanTimeFormat {
  h12,
  h24;

  String format(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    if (this == h24) return '${hour.toString().padLeft(2, '0')}:$minute';
    final suffix = hour < 12 ? 'AM' : 'PM';
    final h12hour = hour % 12 == 0 ? 12 : hour % 12;
    return '$h12hour:$minute $suffix';
  }
}

/// `Viewer.ViewerRelation` (`Block.kt:306-313`): one column of a viewer.
class PlanViewerRelation {
  const PlanViewerRelation({
    required this.key,
    this.isVisible = true,
    this.width = PlanViewerSize.medium,
    this.dateFormat = PlanDateFormat.medium,
    this.timeFormat = PlanTimeFormat.h12,
    this.includeTime = false,
  });

  final String key;
  final bool isVisible;
  final PlanViewerSize width;
  final PlanDateFormat dateFormat;
  final PlanTimeFormat timeFormat;

  /// Date columns only: the value renders with a time appended.
  final bool includeTime;

  PlanViewerRelation copyWith({
    bool? isVisible,
    PlanViewerSize? width,
    PlanDateFormat? dateFormat,
    PlanTimeFormat? timeFormat,
    bool? includeTime,
  }) => PlanViewerRelation(
    key: key,
    isVisible: isVisible ?? this.isVisible,
    width: width ?? this.width,
    dateFormat: dateFormat ?? this.dateFormat,
    timeFormat: timeFormat ?? this.timeFormat,
    includeTime: includeTime ?? this.includeTime,
  );

  Map<String, Object?> toJson() => {
    'key': key,
    'isVisible': isVisible,
    'width': width.name,
    'dateFormat': dateFormat.name,
    'timeFormat': timeFormat.name,
    'includeTime': includeTime,
  };

  static PlanViewerRelation fromJson(Map<String, Object?> json) =>
      PlanViewerRelation(
        key: json['key'] as String? ?? '',
        isVisible: json['isVisible'] != false,
        width: PlanViewerSize.values.firstWhere(
          (value) => value.name == json['width'],
          orElse: () => PlanViewerSize.medium,
        ),
        dateFormat: PlanDateFormat.values.firstWhere(
          (value) => value.name == json['dateFormat'],
          orElse: () => PlanDateFormat.medium,
        ),
        timeFormat: PlanTimeFormat.values.firstWhere(
          (value) => value.name == json['timeFormat'],
          orElse: () => PlanTimeFormat.h12,
        ),
        includeTime: json['includeTime'] == true,
      );
}

/// `Sort.Type` (`Block.kt:335-339`). `custom` is the manual order and is NOT
/// offered in Anytype's sort sheet — the client only ever writes it for
/// favourites and hand-ordered lists (`ModifyViewerSortViewModel.kt:66-96`).
enum PlanSortType {
  asc('ascending'),
  desc('descending'),
  custom('custom');

  const PlanSortType(this.formattedName);

  final String formattedName;

  bool get isOfferedInSheet => this != custom;
}

/// `Sort.EmptyType` (`Block.kt:341-345`): where empty values go.
enum PlanSortEmptyPlacement {
  notSpecific('None'),
  start('Start'),
  end('End');

  const PlanSortEmptyPlacement(this.formattedName);

  final String formattedName;
}

class PlanSort {
  const PlanSort({
    required this.relationKey,
    this.type = PlanSortType.asc,
    this.emptyPlacement = PlanSortEmptyPlacement.notSpecific,
  });

  final String relationKey;
  final PlanSortType type;
  final PlanSortEmptyPlacement emptyPlacement;

  Map<String, Object?> toJson() => {
    'relationKey': relationKey,
    'type': type.name,
    'emptyPlacement': emptyPlacement.name,
  };

  static PlanSort fromJson(Map<String, Object?> json) => PlanSort(
    relationKey: json['relationKey'] as String? ?? '',
    type: PlanSortType.values.firstWhere(
      (value) => value.name == json['type'],
      orElse: () => PlanSortType.asc,
    ),
    emptyPlacement: PlanSortEmptyPlacement.values.firstWhere(
      (value) => value.name == json['emptyPlacement'],
      orElse: () => PlanSortEmptyPlacement.notSpecific,
    ),
  );
}

/// `Filter.Operator` (`Block.kt:366`).
enum PlanFilterOperator { and, or, no }

/// `Filter.Condition` — all 18 (`Block.kt:367-371`).
enum PlanFilterCondition {
  equal,
  notEqual,
  greater,
  less,
  greaterOrEqual,
  lessOrEqual,
  like,
  notLike,
  inSet,
  notIn,
  empty,
  notEmpty,
  allIn,
  notAllIn,
  none,
  exactIn,
  notExactIn,
  exists;

  /// Conditions that need no value field in the sheet.
  bool get isValueless =>
      this == empty || this == notEmpty || this == exists || this == none;

  /// Conditions that compare a set of option ids rather than one.
  bool get isMultiValue =>
      this == inSet ||
      this == notIn ||
      this == allIn ||
      this == notAllIn ||
      this == exactIn ||
      this == notExactIn;

  static const offeredInSheet = <PlanFilterCondition>[
    equal,
    notEqual,
    greater,
    less,
    greaterOrEqual,
    lessOrEqual,
    like,
    notLike,
    empty,
    notEmpty,
    inSet,
    notIn,
    allIn,
    exactIn,
    notExactIn,
  ];
}

/// `Filter.QuickOption` — all 15 date shortcuts (`Block.kt:373-377`). Anytype
/// renders every one of them (`core-ui/.../modals/FilterDateViewHolder.kt:60`).
enum PlanFilterQuickDate {
  exactDate,
  yesterday,
  today,
  tomorrow,
  lastWeek,
  currentWeek,
  nextWeek,
  lastMonth,
  currentMonth,
  nextMonth,
  daysAgo,
  daysAhead,
  lastYear,
  currentYear,
  nextYear;

  /// The inclusive day window a shortcut selects, relative to [now]. The two
  /// relative-count shortcuts need [offset]; callers pass what the sheet holds.
  ({DateTime start, DateTime end}) window({
    required DateTime now,
    int offset = 0,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    ({DateTime start, DateTime end}) day(DateTime value) =>
        (start: value, end: value.add(const Duration(days: 1)));
    switch (this) {
      case PlanFilterQuickDate.exactDate:
        return day(today.add(Duration(days: offset)));
      case PlanFilterQuickDate.yesterday:
        return day(today.subtract(const Duration(days: 1)));
      case PlanFilterQuickDate.today:
        return day(today);
      case PlanFilterQuickDate.tomorrow:
        return day(today.add(const Duration(days: 1)));
      case PlanFilterQuickDate.lastWeek:
        return _week(today, -7);
      case PlanFilterQuickDate.currentWeek:
        return _week(today, 0);
      case PlanFilterQuickDate.nextWeek:
        return _week(today, 7);
      case PlanFilterQuickDate.lastMonth:
        final start = DateTime(now.year, now.month - 1, 1);
        return (start: start, end: DateTime(now.year, now.month, 1));
      case PlanFilterQuickDate.currentMonth:
        return (
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month + 1, 1),
        );
      case PlanFilterQuickDate.nextMonth:
        final start = DateTime(now.year, now.month + 1, 1);
        return (start: start, end: DateTime(now.year, now.month + 2, 1));
      case PlanFilterQuickDate.daysAgo:
        final start = today.subtract(Duration(days: offset));
        return (start: start, end: today.add(const Duration(days: 1)));
      case PlanFilterQuickDate.daysAhead:
        final end = today.add(Duration(days: offset + 1));
        return (start: today, end: end);
      case PlanFilterQuickDate.lastYear:
        return (
          start: DateTime(now.year - 1, 1, 1),
          end: DateTime(now.year, 1, 1),
        );
      case PlanFilterQuickDate.currentYear:
        return (
          start: DateTime(now.year, 1, 1),
          end: DateTime(now.year + 1, 1, 1),
        );
      case PlanFilterQuickDate.nextYear:
        return (
          start: DateTime(now.year + 1, 1, 1),
          end: DateTime(now.year + 2, 1, 1),
        );
    }
  }

  static ({DateTime start, DateTime end}) _week(DateTime today, int shift) {
    // Monday-based week, matching the shortcuts' intent ("this week").
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final start = monday.add(Duration(days: shift));
    return (start: start, end: start.add(const Duration(days: 7)));
  }
}

/// One filter row. `value` is a JSON scalar or list of option ids.
class PlanFilter {
  const PlanFilter({
    required this.relationKey,
    this.operator = PlanFilterOperator.and,
    this.condition = PlanFilterCondition.equal,
    this.value,
    this.quickDate,
    this.offset = 0,
    this.nested,
  });

  final String relationKey;
  final PlanFilterOperator operator;
  final PlanFilterCondition condition;
  final Object? value;

  /// Set when the row was picked from the date shortcuts; the window is
  /// resolved at read time so "today" stays correct tomorrow.
  final PlanFilterQuickDate? quickDate;
  final int offset;

  /// Anytype's nested/advanced row: a rule whose value is itself rules.
  /// `isAdvanced()` (`Block.kt:360-365`) is the desktop-only gate; this client
  /// keeps the shape but does not build a sheet for it.
  final List<PlanFilter>? nested;

  bool get isAdvanced => nested != null && nested!.isNotEmpty;

  Map<String, Object?> toJson() => {
    'relationKey': relationKey,
    'operator': operator.name,
    'condition': condition.name,
    if (value != null) 'value': value,
    if (quickDate != null) 'quickDate': quickDate!.name,
    if (offset != 0) 'offset': offset,
    if (nested != null) 'nested': [for (final row in nested!) row.toJson()],
  };

  static PlanFilter fromJson(Map<String, Object?> json) => PlanFilter(
    relationKey: json['relationKey'] as String? ?? '',
    operator: PlanFilterOperator.values.firstWhere(
      (value) => value.name == json['operator'],
      orElse: () => PlanFilterOperator.and,
    ),
    condition: PlanFilterCondition.values.firstWhere(
      (value) => value.name == json['condition'],
      orElse: () => PlanFilterCondition.equal,
    ),
    value: json['value'],
    quickDate: json['quickDate'] == null
        ? null
        : PlanFilterQuickDate.values.firstWhere(
            (value) => value.name == json['quickDate'],
          ),
    offset: (json['offset'] as num?)?.toInt() ?? 0,
    nested: json['nested'] == null
        ? null
        : [
            for (final row in (json['nested'] as List<Object?>? ?? const []))
              if (row is Map<String, Object?>) PlanFilter.fromJson(row),
          ],
  );
}

/// One viewer of a data view: kind + its own columns, sorts, filters and the
/// card/group options its layout needs (`Block.kt:200-291`).
class PlanViewer {
  const PlanViewer({
    required this.id,
    required this.name,
    required this.kind,
    this.relations = const [],
    this.filters = const [],
    this.sorts = const [],
    this.cardSize = PlanViewerSize.medium,
    this.coverFit = false,
    this.coverRelationKey,
    this.groupRelationKey,
    this.groupBackgroundColors = const [],
    this.hideIcon = false,
    this.defaultTemplateId,
    this.defaultObjectTypeId,
  });

  final String id;
  final String name;
  final PlanViewerKind kind;
  final List<PlanViewerRelation> relations;
  final List<PlanFilter> filters;
  final List<PlanSort> sorts;

  /// Gallery.
  final PlanViewerSize cardSize;
  final bool coverFit;
  final String? coverRelationKey;

  /// Board: the status relation whose options become columns.
  final String? groupRelationKey;
  final List<int> groupBackgroundColors;

  final bool hideIcon;
  final String? defaultTemplateId;
  final String? defaultObjectTypeId;

  List<String> get visibleRelationKeys => [
    for (final relation in relations)
      if (relation.isVisible) relation.key,
  ];

  PlanViewerRelation? relation(String key) {
    for (final entry in relations) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  PlanViewer copyWith({
    String? name,
    PlanViewerKind? kind,
    List<PlanViewerRelation>? relations,
    List<PlanFilter>? filters,
    List<PlanSort>? sorts,
    PlanViewerSize? cardSize,
    bool? coverFit,
    String? coverRelationKey,
    String? groupRelationKey,
    List<int>? groupBackgroundColors,
    bool? hideIcon,
    String? defaultTemplateId,
    String? defaultObjectTypeId,
  }) => PlanViewer(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    relations: relations ?? this.relations,
    filters: filters ?? this.filters,
    sorts: sorts ?? this.sorts,
    cardSize: cardSize ?? this.cardSize,
    coverFit: coverFit ?? this.coverFit,
    coverRelationKey: coverRelationKey ?? this.coverRelationKey,
    groupRelationKey: groupRelationKey ?? this.groupRelationKey,
    groupBackgroundColors: groupBackgroundColors ?? this.groupBackgroundColors,
    hideIcon: hideIcon ?? this.hideIcon,
    defaultTemplateId: defaultTemplateId ?? this.defaultTemplateId,
    defaultObjectTypeId: defaultObjectTypeId ?? this.defaultObjectTypeId,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'relations': [for (final r in relations) r.toJson()],
    'filters': [for (final f in filters) f.toJson()],
    'sorts': [for (final s in sorts) s.toJson()],
    'cardSize': cardSize.name,
    'coverFit': coverFit,
    if (coverRelationKey != null) 'coverRelationKey': coverRelationKey,
    if (groupRelationKey != null) 'groupRelationKey': groupRelationKey,
    'groupBackgroundColors': groupBackgroundColors,
    'hideIcon': hideIcon,
    if (defaultTemplateId != null) 'defaultTemplateId': defaultTemplateId,
    if (defaultObjectTypeId != null) 'defaultObjectTypeId': defaultObjectTypeId,
  };

  static PlanViewer fromJson(Map<String, Object?> json) => PlanViewer(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    kind: PlanViewerKind.fromName(json['kind'] as String? ?? 'grid'),
    relations: [
      for (final entry in (json['relations'] as List<Object?>? ?? const []))
        if (entry is Map<String, Object?>) PlanViewerRelation.fromJson(entry),
    ],
    filters: [
      for (final entry in (json['filters'] as List<Object?>? ?? const []))
        if (entry is Map<String, Object?>) PlanFilter.fromJson(entry),
    ],
    sorts: [
      for (final entry in (json['sorts'] as List<Object?>? ?? const []))
        if (entry is Map<String, Object?>) PlanSort.fromJson(entry),
    ],
    cardSize: PlanViewerSize.values.firstWhere(
      (value) => value.name == json['cardSize'],
      orElse: () => PlanViewerSize.medium,
    ),
    coverFit: json['coverFit'] == true,
    coverRelationKey: json['coverRelationKey'] as String?,
    groupRelationKey: json['groupRelationKey'] as String?,
    groupBackgroundColors: [
      for (final value
          in (json['groupBackgroundColors'] as List<Object?>? ?? const []))
        if (value is num) value.toInt(),
    ],
    hideIcon: json['hideIcon'] == true,
    defaultTemplateId: json['defaultTemplateId'] as String?,
    defaultObjectTypeId: json['defaultObjectTypeId'] as String?,
  );
}

/// The data view itself: its viewers, the active one, and the two order lists
/// (`Block.kt:273-274 objectOrders` / `groupOrders`). Records are NOT held
/// here — the store owns content, the view owns ids (Anytype's split,
/// `sets/ObjectSetDatabase.kt:24`).
class PlanDataView {
  const PlanDataView({
    this.viewers = const [],
    this.activeViewerId,
    this.objectOrders = const {},
    this.groupOrders = const {},
  });

  final List<PlanViewer> viewers;
  final String? activeViewerId;

  /// Manual order per viewer id; the `custom` sort reads it.
  final Map<String, List<String>> objectOrders;

  /// Column order per board viewer id.
  final Map<String, List<String>> groupOrders;

  PlanViewer? get activeViewer {
    for (final viewer in viewers) {
      if (viewer.id == activeViewerId) return viewer;
    }
    return viewers.isEmpty ? null : viewers.first;
  }

  PlanViewer? viewerById(String id) {
    for (final viewer in viewers) {
      if (viewer.id == id) return viewer;
    }
    return null;
  }

  /// One place that rebuilds a data view. Seven call sites in the store used to
  /// spell all four fields out by hand — a fifth field would have been a
  /// silent drop in six of them.
  PlanDataView copyWith({
    List<PlanViewer>? viewers,
    String? activeViewerId,
    Map<String, List<String>>? objectOrders,
    Map<String, List<String>>? groupOrders,
  }) => PlanDataView(
    viewers: viewers ?? this.viewers,
    activeViewerId: activeViewerId ?? this.activeViewerId,
    objectOrders: objectOrders ?? this.objectOrders,
    groupOrders: groupOrders ?? this.groupOrders,
  );

  Map<String, Object?> toJson() => {
    'viewers': [for (final v in viewers) v.toJson()],
    if (activeViewerId != null) 'activeViewerId': activeViewerId,
    if (objectOrders.isNotEmpty)
      'objectOrders': objectOrders.map((k, v) => MapEntry(k, v)),
    if (groupOrders.isNotEmpty)
      'groupOrders': groupOrders.map((k, v) => MapEntry(k, v)),
  };

  static PlanDataView fromJson(Map<String, Object?> json) {
    Map<String, List<String>> decodeOrders(Object? raw) {
      if (raw is! Map) return const {};
      return {
        for (final entry in raw.entries)
          if (entry.key is String && entry.value is List)
            entry.key as String: [
              for (final id in (entry.value as List<Object?>))
                if (id is String) id,
            ],
      };
    }

    return PlanDataView(
      viewers: [
        for (final entry in (json['viewers'] as List<Object?>? ?? const []))
          if (entry is Map<String, Object?>) PlanViewer.fromJson(entry),
      ],
      activeViewerId: json['activeViewerId'] as String?,
      objectOrders: decodeOrders(json['objectOrders']),
      groupOrders: decodeOrders(json['groupOrders']),
    );
  }
}

/// Set / Collection / TypeSet. Anytype's three states have identical members
/// (`sets/state/ObjectState.kt:17-77`); what differs is identity and where the
/// records come from.
enum PlanCollectionKind {
  /// Records by filter over a source type — Anytype's `DataView.Set`.
  set,

  /// An explicit membership list — `DataView.Collection`.
  collection,

  /// A set generated from an object type — `DataView.TypeSet`.
  typeSet;

  /// Both set flavours skip the template picker on creation
  /// (`ObjectTypeExtensions.kt:107-130`).
  bool get skipsTemplatePicker => this != collection;
}

/// The seven view-management actions Anytype's viewer menu offers
/// (`sets/ViewerEditWidgetUi.kt:30-40`).
enum PlanViewerEditAction {
  updateName,
  layout,
  relations,
  filters,
  sorts,
  duplicate,
  delete,
}

/// A set or a collection: the surface that owns a [PlanDataView].
///
/// `Set` and `TypeSet` resolve their records through filters over a source
/// type; `Collection` keeps an explicit membership list — which is exactly the
/// difference upstream draws between `DataView.Set` and `DataView.Collection`
/// (`sets/state/ObjectState.kt:17-77`, identical members, different identity).
class PlanCollection {
  const PlanCollection({
    required this.id,
    required this.name,
    required this.kind,
    this.sourceTypeKey,
    this.members = const [],
    this.dataView = const PlanDataView(),
    this.restrictions = const {},
    this.iconEmoji,
    this.description,
  });

  final String id;
  final String name;
  final PlanCollectionKind kind;

  /// The type a set queries; null for a collection.
  final String? sourceTypeKey;

  /// Explicit membership, in the order it was added.
  final List<String> members;
  final PlanDataView dataView;
  final Set<PlanDataViewRestriction> restrictions;
  final String? iconEmoji;
  final String? description;

  PlanViewer? get activeViewer => dataView.activeViewer;

  /// Which records this collection is about to show: a collection answers with
  /// its own list, a set with every record of its source type.
  List<String> candidateRecordIds(Iterable<PlanObject> all) => switch (kind) {
    PlanCollectionKind.collection => members,
    _ => [
      for (final object in all)
        if (sourceTypeKey == null || object.typeKey == sourceTypeKey) object.id,
    ],
  };

  PlanCollection copyWith({
    String? name,
    List<String>? members,
    PlanDataView? dataView,
    Set<PlanDataViewRestriction>? restrictions,
    String? iconEmoji,
    String? description,
  }) => PlanCollection(
    id: id,
    name: name ?? this.name,
    kind: kind,
    sourceTypeKey: sourceTypeKey,
    members: members ?? this.members,
    dataView: dataView ?? this.dataView,
    restrictions: restrictions ?? this.restrictions,
    iconEmoji: iconEmoji ?? this.iconEmoji,
    description: description ?? this.description,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    if (sourceTypeKey != null) 'sourceTypeKey': sourceTypeKey,
    'members': members,
    'dataView': dataView.toJson(),
    'restrictions': [for (final r in restrictions) r.name],
    if (iconEmoji != null) 'iconEmoji': iconEmoji,
    if (description != null) 'description': description,
  };

  static PlanCollection fromJson(Map<String, Object?> json) => PlanCollection(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    kind: PlanCollectionKind.values.firstWhere(
      (value) => value.name == json['kind'],
      orElse: () => PlanCollectionKind.collection,
    ),
    sourceTypeKey: json['sourceTypeKey'] as String?,
    members: [
      for (final id in (json['members'] as List<Object?>? ?? const []))
        if (id is String) id,
    ],
    dataView: PlanDataView.fromJson(
      (json['dataView'] as Map<String, Object?>?) ?? const {},
    ),
    restrictions: {
      for (final name in (json['restrictions'] as List<Object?>? ?? const []))
        if (name is String)
          PlanDataViewRestriction.values.firstWhere(
            (value) => value.name == name,
            orElse: () => PlanDataViewRestriction.views,
          ),
    },
    iconEmoji: json['iconEmoji'] as String?,
    description: json['description'] as String?,
  );
}
