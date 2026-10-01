// Workbench preferences — the settings that change how panels behave, not what
// the agent is.
//
// A port of `DSH-better-sidebar/src/prefs-shared.ts`, narrowed to the three
// groups this build consumes: the terminal card (font, bottom-panel seeding)
// and the per-tab enable switches. Kept OUT of [AppSettings] on purpose, as the
// plan records: layout-class preferences must never travel the
// `requiresRuntimeRestart` channel, because rebuilding the agent to change a
// font would be a bug, not a feature.
//
// Semantics carried over from the source, worth restating because both are
// load-bearing:
//
//   * The tab switches are absent-means-enabled. Only an explicit `false`
//     disables a type, so a document written by an older or newer build keeps
//     every type it never mentioned.
//   * A disabled type hides from the `+` menu and the opens refuse — but
//     already-open tabs keep rendering, since closing them would edit a
//     conversation's saved layout behind its back.

/// Range contract of the terminal font size — the source's
/// `TERMINAL_FONT_SIZE_MIN/MAX/DEFAULT`.
const terminalFontSizeMin = 9;
const terminalFontSizeMax = 32;

/// The size the terminal renders at when the user has not chosen one. 13 is the
/// source's own default, kept over this app's earlier hardcoded 12 so the
/// port agrees with the design it is porting.
const terminalFontSizeDefault = 13;

/// How the agent's history list is arranged (ADR-0039 D3).
///
/// `project` is the reference implementation's own default
/// (`sidebarTaskPreferences.ts:12`). `flat` stays available on purpose: a user
/// who works in one folder gains nothing from a grouping layer, and hiding the
/// choice would make the new default feel imposed.
enum HistoryOrganize { project, flat }

class WorkbenchPrefs {
  const WorkbenchPrefs({
    this.bottomPanelAutoTerminal = true,
    this.terminalFontFamily = '',
    this.terminalFontSize = terminalFontSizeDefault,
    this.tabsEnabled = const {},
    this.historyOrganize = HistoryOrganize.project,
    this.collapsedWorkspaces = const {},
  });

  WorkbenchPrefs.fromJson(Map<String, dynamic> json)
    : bottomPanelAutoTerminal = json['bottomPanelAutoTerminal'] != false,
      terminalFontFamily = json['terminalFontFamily'] as String? ?? '',
      terminalFontSize = clampTerminalFontSize(
        json['terminalFontSize'] as num? ?? terminalFontSizeDefault,
      ),
      tabsEnabled = _readTabsEnabled(json['tabsEnabled']),
      historyOrganize = HistoryOrganize.values.firstWhere(
        (option) => option.name == json['historyOrganize'],
        orElse: () => HistoryOrganize.project,
      ),
      collapsedWorkspaces = _readCollapsed(json['collapsedWorkspaces']);

  /// Whether expanding the bottom panel for the FIRST time in a session tries
  /// to open a fresh terminal tab there.
  final bool bottomPanelAutoTerminal;

  /// Custom terminal font family stack. Empty follows the theme's code font.
  final String terminalFontFamily;

  /// Terminal font size in px, clamped to the contract range at every read.
  final int terminalFontSize;

  /// Per-tab enable switches, keyed by tab type. Absent means enabled; only an
  /// explicit `false` disables.
  final Map<String, bool> tabsEnabled;

  /// The history list's arrangement.
  final HistoryOrganize historyOrganize;

  /// The folders folded up in the history, keyed by `workspaceKey` — not by
  /// display name and not by raw path, so `/var/...` and `/private/var/...`
  /// stay one folder with one fold state.
  final Set<String> collapsedWorkspaces;

  bool workspaceCollapsed(String key) => collapsedWorkspaces.contains(key);

  WorkbenchPrefs withHistoryOrganize(HistoryOrganize organize) =>
      copyWith(historyOrganize: organize);

  WorkbenchPrefs withWorkspaceCollapsed(String key, bool collapsed) {
    final next = Set.of(collapsedWorkspaces);
    if (collapsed) {
      next.add(key);
    } else {
      next.remove(key);
    }
    return copyWith(collapsedWorkspaces: Set.unmodifiable(next));
  }

  /// Whether [type] may be opened — absent or true is yes.
  bool tabEnabled(String type) => tabsEnabled[type] != false;

  /// Flips [type]'s switch, keeping the absent-means-enabled economy: enabling
  /// a type removes its key rather than storing a redundant `true`.
  WorkbenchPrefs withTabEnabled(String type, bool enabled) {
    final next = Map.of(tabsEnabled);
    if (enabled) {
      next.remove(type);
    } else {
      next[type] = false;
    }
    // Through copyWith, not a fresh constructor call: an earlier version listed
    // every field by hand, and any field added afterwards would have been reset
    // by toggling a tab — a collapsed folder springing open for an unrelated
    // edit.
    return copyWith(tabsEnabled: Map.unmodifiable(next));
  }

  WorkbenchPrefs copyWith({
    bool? bottomPanelAutoTerminal,
    String? terminalFontFamily,
    int? terminalFontSize,
    Map<String, bool>? tabsEnabled,
    HistoryOrganize? historyOrganize,
    Set<String>? collapsedWorkspaces,
  }) => WorkbenchPrefs(
    bottomPanelAutoTerminal:
        bottomPanelAutoTerminal ?? this.bottomPanelAutoTerminal,
    terminalFontFamily: terminalFontFamily ?? this.terminalFontFamily,
    terminalFontSize: terminalFontSize ?? this.terminalFontSize,
    tabsEnabled: tabsEnabled ?? this.tabsEnabled,
    historyOrganize: historyOrganize ?? this.historyOrganize,
    collapsedWorkspaces: collapsedWorkspaces ?? this.collapsedWorkspaces,
  );

  Map<String, dynamic> toJson() => {
    'bottomPanelAutoTerminal': bottomPanelAutoTerminal,
    'terminalFontFamily': terminalFontFamily,
    'terminalFontSize': terminalFontSize,
    if (tabsEnabled.isNotEmpty) 'tabsEnabled': tabsEnabled,
    'historyOrganize': historyOrganize.name,
    if (collapsedWorkspaces.isNotEmpty)
      'collapsedWorkspaces': [...collapsedWorkspaces],
  };

  static Map<String, bool> _readTabsEnabled(Object? raw) {
    if (raw is! Map) return const {};
    return Map.unmodifiable({
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is bool)
          entry.key as String: entry.value as bool,
    });
  }

  @override
  bool operator ==(Object other) =>
      other is WorkbenchPrefs &&
      other.bottomPanelAutoTerminal == bottomPanelAutoTerminal &&
      other.terminalFontFamily == terminalFontFamily &&
      other.terminalFontSize == terminalFontSize &&
      other.historyOrganize == historyOrganize &&
      _mapEq(other.tabsEnabled, tabsEnabled) &&
      other.collapsedWorkspaces.length == collapsedWorkspaces.length &&
      other.collapsedWorkspaces.containsAll(collapsedWorkspaces);

  @override
  int get hashCode => Object.hash(
    bottomPanelAutoTerminal,
    terminalFontFamily,
    terminalFontSize,
    historyOrganize,
    Object.hashAllUnordered(
      tabsEnabled.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    Object.hashAllUnordered(collapsedWorkspaces),
  );

  static Set<String> _readCollapsed(Object? raw) {
    if (raw is! List) return const {};
    return Set.unmodifiable({
      for (final entry in raw)
        if (entry is String && entry.isNotEmpty) entry,
    });
  }

  static bool _mapEq(Map<String, bool> a, Map<String, bool> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}

/// Clamps a font size into the contract range, as the source's
/// `clampTerminalFontSize` does on every read.
int clampTerminalFontSize(num value) =>
    value.round().clamp(terminalFontSizeMin, terminalFontSizeMax);
