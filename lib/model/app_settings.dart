// Everything the app remembers between launches.
//
// Three halves kept in one document because they are saved by one screen: the
// model connection, the workspace folder, and the agent's extension surface
// (MCP servers, skills directory). They differ in what a change costs — the
// model fields and the extension surface are baked into a runtime and need a
// new one, the workspace is a live setter — so they stay separate fields rather
// than being flattened.
//
// Beside those sit the general preferences: the theme mode and the recent
// workspaces. Neither needs a runtime rebuild, and neither is "saved" by the
// settings screen — they apply on write.

import 'mcp_settings.dart';
import 'model_settings.dart';

/// How the app's brightness follows the system — dsh's appearance item.
enum ThemeMode {
  light,
  dark,
  system;

  String get name => switch (this) {
    light => 'light',
    dark => 'dark',
    system => 'system',
  };

  static ThemeMode fromName(String? raw) => switch (raw) {
    'light' => light,
    'dark' => dark,
    _ => system,
  };
}

/// How the app's language follows the system — dsh's zh/en pair. `system`
/// resolves against `Platform.localeName` once, in main; the persisted value
/// is the override only.
enum LocaleMode {
  system,
  en,
  zh;

  String get name => switch (this) {
    system => 'system',
    en => 'en',
    zh => 'zh',
  };

  static LocaleMode fromName(String? raw) => switch (raw) {
    'en' => en,
    'zh' => zh,
    _ => system,
  };
}

class AppSettings {
  const AppSettings({
    this.model = const ModelSettings(),
    this.workspaceRoot,
    this.workspaceBookmark,
    this.mcpServers = const [],
    this.skillsRoot,
    this.theme = ThemeMode.system,
    this.locale = LocaleMode.system,
    this.recentWorkspaces = const [],
  });

  AppSettings.fromJson(Map<String, dynamic> json)
    : model = ModelSettings.fromJson(
        json['model'] as Map<String, dynamic>? ?? const {},
      ),
      workspaceRoot = json['workspaceRoot'] as String?,
      workspaceBookmark = json['workspaceBookmark'] as String?,
      mcpServers = [
        for (final entry in (json['mcpServers'] as List? ?? const []))
          ?McpServerConfig.fromJson(entry),
      ],
      skillsRoot = json['skillsRoot'] as String?,
      theme = ThemeMode.fromName(json['theme'] as String?),
      locale = LocaleMode.fromName(json['locale'] as String?),
      recentWorkspaces = [
        for (final path in (json['recentWorkspaces'] as List? ?? const []))
          if (path is String) path,
      ];

  final ModelSettings model;

  /// The theme mode the app renders with. `system` follows the platform.
  final ThemeMode theme;

  /// The language the UI renders in. `system` follows the platform, resolved
  /// once at launch; an explicit choice rides the document like the theme.
  final LocaleMode locale;

  /// The folder the file and shell tools are confined to. Null means they refuse
  /// every call, which is the state a fresh install is in — there is
  /// no defensible default, since the app cannot guess which folder the user
  /// meant to expose.
  final String? workspaceRoot;

  /// The security-scoped bookmark for [workspaceRoot], as handed back by the
  /// native folder pick (see `ProjectFolderOps`). Resolved at launch to
  /// restore access to the folder across restarts — the path alone is only a
  /// name; the bookmark is the permission that travels with it. Null when the
  /// root was adopted from a typed path or a recent entry rather than picked,
  /// or on platforms without bookmarks; those cases live without the restore
  /// step rather than without the workspace.
  final String? workspaceBookmark;

  /// MCP servers the agent may call, namespaced `mcp/<name>:tool/<tool>`.
  final List<McpServerConfig> mcpServers;

  /// Where `SKILL.md` skill folders live. Null means the default
  /// `<support>/skills`, which is what the runtime is handed when the user has
  /// not chosen one.
  final String? skillsRoot;

  /// Folders offered back in the picker, most recent first, deduped. A
  /// workspace that no longer exists on disk keeps its seat — the picker shows
  /// it as missing rather than silently forgetting a place the user knew.
  final List<String> recentWorkspaces;

  /// Moves [path] to the front of [recentWorkspaces], capped, deduped. The
  /// picker's history is the record of where the user has been; a folder that
  /// lost its seat on the way out would be a folder the picker forgets.
  static List<String> _pushRecent(List<String> recent, String path) => [
    path,
    for (final other in recent)
      if (other != path) other,
  ].take(8).toList();

  AppSettings copyWith({
    ModelSettings? model,
    String? workspaceRoot,
    String? workspaceBookmark,
    List<McpServerConfig>? mcpServers,
    String? skillsRoot,
    ThemeMode? theme,
    LocaleMode? locale,
    List<String>? recentWorkspaces,
  }) => AppSettings(
    model: model ?? this.model,
    workspaceRoot: workspaceRoot ?? this.workspaceRoot,
    workspaceBookmark: workspaceBookmark ?? this.workspaceBookmark,
    mcpServers: mcpServers ?? this.mcpServers,
    skillsRoot: skillsRoot ?? this.skillsRoot,
    theme: theme ?? this.theme,
    locale: locale ?? this.locale,
    recentWorkspaces: recentWorkspaces ?? this.recentWorkspaces,
  );

  /// Explicit, because [copyWith] cannot express it: an empty path field means
  /// "take the permission back", not "leave it alone". The bookmark goes with
  /// it — a permission for a workspace that no longer exists is a lie the
  /// restore step would have to catch anyway.
  AppSettings withoutWorkspace() => AppSettings(
    model: model,
    mcpServers: mcpServers,
    skillsRoot: skillsRoot,
    theme: theme,
    locale: locale,
    recentWorkspaces: recentWorkspaces,
  );

  /// [path] adopted as the workspace — pointed at and moved to the front of
  /// the recent list in one write, so the two can never disagree. The bookmark
  /// is the pick's own; adopting a typed path or a recent entry (`bookmark`
  /// null) clears any previous one: a stale bookmark for a folder that is no
  /// longer the root would restore the wrong permission.
  AppSettings withWorkspace(String path, {String? bookmark}) => AppSettings(
    model: model,
    workspaceRoot: path,
    workspaceBookmark: bookmark,
    mcpServers: mcpServers,
    skillsRoot: skillsRoot,
    theme: theme,
    locale: locale,
    recentWorkspaces: _pushRecent(recentWorkspaces, path),
  );

  /// Forgets [path] from the recent list only — the picker's business, not the
  /// permission's.
  AppSettings forgetWorkspace(String path) => copyWith(
    recentWorkspaces: [
      for (final other in recentWorkspaces)
        if (other != path) other,
    ],
  );

  /// Whether the runtime built from [previous] has to be torn down for these
  /// settings: the model fields, the MCP server set, and the skills directory
  /// are all baked in at construction.
  bool requiresRuntimeRestart(AppSettings previous) =>
      model.requiresRestart(previous.model) ||
      !_listEq(mcpServers, previous.mcpServers) ||
      skillsRoot != previous.skillsRoot;

  Map<String, dynamic> toJson() => {
    'model': model.toJson(),
    if (workspaceRoot != null) 'workspaceRoot': workspaceRoot,
    if (workspaceBookmark != null) 'workspaceBookmark': workspaceBookmark,
    if (mcpServers.isNotEmpty)
      'mcpServers': [for (final server in mcpServers) server.toJson()],
    if (skillsRoot != null) 'skillsRoot': skillsRoot,
    if (theme != ThemeMode.system) 'theme': theme.name,
    if (locale != LocaleMode.system) 'locale': locale.name,
    if (recentWorkspaces.isNotEmpty) 'recentWorkspaces': recentWorkspaces,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.model == model &&
      other.workspaceRoot == workspaceRoot &&
      other.workspaceBookmark == workspaceBookmark &&
      _listEq(other.mcpServers, mcpServers) &&
      other.skillsRoot == skillsRoot &&
      other.theme == theme &&
      other.locale == locale &&
      _listEq(other.recentWorkspaces, recentWorkspaces);

  @override
  int get hashCode => Object.hash(
    model,
    workspaceRoot,
    workspaceBookmark,
    Object.hashAll(mcpServers),
    skillsRoot,
    theme,
    locale,
    Object.hashAll(recentWorkspaces),
  );

  /// Lists have no deep `==` of their own — a fresh `[]` is not `const []` —
  /// so equality here has to walk the elements. `McpServerConfig` itself has a
  /// proper `==`, which is what makes the walk meaningful.
  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
