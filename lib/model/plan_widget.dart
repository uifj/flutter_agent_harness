// Home widgets (ADR-0037 §7). The thirteen forms are Anytype's
// `WidgetView` subclasses (`presentation/.../widgets/WidgetView.kt:35-368`),
// the five layouts are `WidgetTypeView.kt:12-16` backed by
// `Block.Content.Widget.Layout` codes (`Block.kt:423-426`), the seven bundled
// sources are `core-models/.../widgets/Widgets.kt:4-12`, and the sections are
// `presentation/.../widgets/Widget.kt:36-42`.
//
// Two upstream answers are reproduced on purpose: a widget has NO size concept
// (only a layout), and its row count is a relation (`widgetLimit`,
// `core-models/.../Relations.kt:136`) rather than a UI number.

/// `Block.Content.Widget.Layout` — codes kept identical to upstream.
enum PlanWidgetLayout {
  tree(1),
  link(0),
  list(2),
  compactList(3),
  view(4);

  const PlanWidgetLayout(this.code);

  final int code;

  static PlanWidgetLayout fromCode(int code) => values.firstWhere(
    (value) => value.code == code,
    orElse: () => list,
  );
}

/// `BundledWidgetSourceIds` (`widgets/Widgets.kt:4-12`).
abstract final class PlanBundledWidgetSourceIds {
  static const favorite = 'favorite';
  static const recent = 'recent';
  static const recentLocal = 'recentOpen';
  static const bin = 'bin';
  static const allObjects = 'allObjects';
  static const chat = 'chat';
  static const personalFavorites = 'personalFavorites';

  static const ids = <String>[
    favorite,
    recent,
    recentLocal,
    bin,
    allObjects,
    chat,
    personalFavorites,
  ];
}

/// `SectionType` (`presentation/.../widgets/Widget.kt:36-42`): the bands the
/// home strip paints in this order.
enum PlanWidgetSection {
  pinned,
  unread,
  myFavorites,
  types,
  recentlyEdited;

  static const order = <PlanWidgetSection>[
    pinned,
    unread,
    myFavorites,
    types,
    recentlyEdited,
  ];
}

/// The rendered form a widget resolves to. Upstream has thirteen
/// (`WidgetView.kt`) plus three auxiliary states; the chat-shaped ones read
/// this app's conversation sessions rather than an object type, because the
/// plan workspace has no chat objects — see ADR-0037 "chat 组件的源" mapping.
enum PlanWidgetForm {
  tree,
  link,
  setOfObjects,
  gallery,
  chatList,
  unreadChatList,
  recentlyEdited,
  listOfObjects,
  bin,
  allContent,
  spaceChat,
  objectTypesGroup,
  home,
  emptyState,
  inviteMembers,
  counter;

  static const forms = <PlanWidgetForm>[
    tree,
    link,
    setOfObjects,
    gallery,
    chatList,
    unreadChatList,
    recentlyEdited,
    listOfObjects,
    bin,
    allContent,
    spaceChat,
    objectTypesGroup,
    home,
  ];

  /// The three helper states are rendered inside a form, not as widgets.
  static const auxiliary = <PlanWidgetForm>[emptyState, inviteMembers, counter];

  /// Which layout a given source+layout pair draws as. Mirrors upstream's
  /// `WidgetView` selection: a bundled Bin cannot be a tree, a Link is one row.
  static PlanWidgetForm resolve({
    required PlanWidgetLayout layout,
    required bool isBundledSource,
    required String? bundledId,
  }) {
    if (isBundledSource) {
      return switch (bundledId) {
        PlanBundledWidgetSourceIds.bin => bin,
        PlanBundledWidgetSourceIds.allObjects => allContent,
        PlanBundledWidgetSourceIds.chat => spaceChat,
        PlanBundledWidgetSourceIds.favorite ||
        PlanBundledWidgetSourceIds.personalFavorites => listOfObjects,
        PlanBundledWidgetSourceIds.recent ||
        PlanBundledWidgetSourceIds.recentLocal => recentlyEdited,
        _ => listOfObjects,
      };
    }
    return switch (layout) {
      PlanWidgetLayout.tree => tree,
      PlanWidgetLayout.link => link,
      PlanWidgetLayout.list => setOfObjects,
      PlanWidgetLayout.compactList => listOfObjects,
      PlanWidgetLayout.view => gallery,
    };
  }
}

/// A widget's source: either a concrete object/set, or one of the seven
/// bundled ids (`Widget.Source.Default` / `.Bundled`, `Widget.kt:192-235`).
sealed class PlanWidgetSource {
  const PlanWidgetSource();

  bool get isBundled => this is Bundled;

  /// A bundled source has no object to open, so "remove the object" actions
  /// do not apply to it.
  bool get canBeOpened => !isBundled;

  class Default extends PlanWidgetSource {
    const Default(this.objectId);

    final String objectId;
  }

  class Bundled extends PlanWidgetSource {
    const Bundled(this.id);

    final String id;
  }
}

/// One widget in the home strip.
class PlanWidget {
  const PlanWidget({
    required this.id,
    required this.source,
    this.layout = PlanWidgetLayout.list,
    this.limit,
    this.activeViewId,
    this.section = PlanWidgetSection.pinned,
  });

  final String id;
  final PlanWidgetSource source;
  final PlanWidgetLayout layout;

  /// Null means "use the relation default"; upstream stores the limit as a
  /// relation on the widget object rather than as a field.
  final int? limit;
  final String? activeViewId;
  final PlanWidgetSection section;

  PlanWidgetForm get form => PlanWidgetForm.resolve(
    layout: layout,
    isBundledSource: source.isBundled,
    bundledId: source is PlanWidgetSource.Bundled
        ? (source as PlanWidgetSource.Bundled).id
        : null,
  );

  String? get objectId => switch (source) {
    final PlanWidgetSource.Default value => value.objectId,
    _ => null,
  };

  /// `WidgetConfig.resolveListWidgetLimit` (`WidgetConfig.kt:36`): a widget
  /// without a stored limit reads the default, and the default is not zero —
  /// an empty list is not a legal rendering of "no preference".
  int resolvedLimit({int defaultLimit = 6}) {
    final value = limit ?? defaultLimit;
    return value <= 0 ? defaultLimit : value;
  }

  PlanWidget copyWith({
    PlanWidgetSource? source,
    PlanWidgetLayout? layout,
    int? limit,
    String? activeViewId,
    PlanWidgetSection? section,
  }) => PlanWidget(
    id: id,
    source: source ?? this.source,
    layout: layout ?? this.layout,
    limit: limit ?? this.limit,
    activeViewId: activeViewId ?? this.activeViewId,
    section: section ?? this.section,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'source': source.isBundled
        ? (source as PlanWidgetSource.Bundled).id
        : (source as PlanWidgetSource.Default).objectId,
    'bundled': source.isBundled,
    'layout': layout.code,
    if (limit != null) 'limit': limit,
    if (activeViewId != null) 'activeViewId': activeViewId,
    'section': section.name,
  };

  static PlanWidget fromJson(Map<String, Object?> json) {
    final isBundled = json['bundled'] == true;
    final key = json['source'] as String? ?? '';
    return PlanWidget(
      id: json['id'] as String? ?? '',
      source: isBundled
          ? PlanWidgetSource.Bundled(key)
          : PlanWidgetSource.Default(key),
      layout: PlanWidgetLayout.fromCode(
        (json['layout'] as num?)?.toInt() ?? PlanWidgetLayout.list.code,
      ),
      limit: (json['limit'] as num?)?.toInt(),
      activeViewId: json['activeViewId'] as String?,
      section: PlanWidgetSection.values.firstWhere(
        (value) => value.name == json['section'],
        orElse: () => PlanWidgetSection.pinned,
      ),
    );
  }
}

/// The widget dropdown's actions (`WidgetView.kt:408-419`).
enum PlanWidgetAction {
  changeType,
  removeWidget,
  emptyBin,
  changeHome,
  favoriteObject,
  unfavoriteObject,
  createObjectOfType;

  /// Only a Bin widget offers "empty bin"; only a source that names an object
  /// can be favourited — Anytype gates both on the source, not the layout.
  static bool applies(
    PlanWidgetAction action,
    PlanWidget widget,
  ) => switch (action) {
    PlanWidgetAction.emptyBin => widget.source.isBundled &&
        (widget.source as PlanWidgetSource.Bundled).id ==
            PlanBundledWidgetSourceIds.bin,
    PlanWidgetAction.favoriteObject ||
    PlanWidgetAction.unfavoriteObject ||
    PlanWidgetAction.createObjectOfType => widget.source.canBeOpened,
    _ => true,
  };
}

/// Ordering result for the strip: widgets within a section keep their stored
/// order, sections follow `PlanWidgetSection.order`.
List<PlanWidget> orderPlanWidgets(Iterable<PlanWidget> widgets) {
  final bySection = <PlanWidgetSection, List<PlanWidget>>{};
  for (final widget in widgets) {
    (bySection[widget.section] ??= <PlanWidget>[]).add(widget);
  }
  return [
    for (final section in PlanWidgetSection.order)
      ...bySection[section] ?? const <PlanWidget>[],
  ];
}
