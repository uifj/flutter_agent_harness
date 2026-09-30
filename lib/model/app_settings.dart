// Everything the app remembers between launches.
//
// Three halves kept in one document because they are saved by one screen: the
// model connection, the workspace folder, and the agent's extension surface
// (MCP servers, skills directory). They differ in what a change costs — the
// model fields and the extension surface are baked into a runtime and need a
// new one, the workspace is a live setter — so they stay separate fields rather
// than being flattened.
//
// Beside those sit the general/appearance preferences: theme, language, the
// conversation font/width, preview mode, and the tool-call/prompt-suggestion
// behaviour toggles (ADR-0005, ported from starkins_app's preferences). None
// rebuilds the runtime, so none is "saved" the way the model fields are — they
// apply on write and persist across launches.
//
// Persistence stays in ONE document (this), not a second in-memory preferences
// model: the ADR's guard against two sources of truth.

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

/// The app's text-size step. Multiplied into the system's own `TextScaler` at
/// the root (`main.dart`), so it composes with the OS's "放大文本" instead of
/// replacing it — which is why it is a factor and not a pixel size.
enum AppFontSize {
  small,
  medium,
  large;

  String get name => switch (this) {
    small => 'small',
    medium => 'medium',
    large => 'large',
  };
  static AppFontSize fromName(String? raw) => switch (raw) {
    'small' => small,
    'large' => large,
    _ => medium,
  };

  /// The default is exactly 1.0: choosing "medium" must change nothing, and a
  /// factor is what lets the root multiply it into the platform's scaler.
  double get scale => switch (this) {
    small => 0.9,
    medium => 1.0,
    large => 1.15,
  };
}

/// The conversation column's max width class. Wired into `LayoutController`
/// at ADR-0005 S4; stored here so the choice persists.
enum AppConversationWidth {
  normal,
  wide;

  String get name => switch (this) {
    normal => 'normal',
    wide => 'wide',
  };
  static AppConversationWidth fromName(String? raw) =>
      raw == 'wide' ? wide : normal;
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
    this.fontSize = AppFontSize.medium,
    this.conversationWidth = AppConversationWidth.normal,
    this.expandToolCalls = true,
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
      ],
      fontSize = AppFontSize.fromName(json['fontSize'] as String?),
      conversationWidth = AppConversationWidth.fromName(
        json['conversationWidth'] as String?,
      ),
      expandToolCalls = json['expandToolCalls'] as bool? ?? true;

  final ModelSettings model;

  /// The theme mode the app renders with. `system` follows the platform.
  final ThemeMode theme;

  /// The language the UI renders in. `system` follows the platform, resolved
  /// once at launch; an explicit choice rides the document like the theme.
  final LocaleMode locale;

  /// The folder the file and shell tools are confined to. Null means they refuse
  /// every call, which is the state a fresh install is in.
  final String? workspaceRoot;

  /// The security-scoped bookmark for [workspaceRoot], restored at launch (see
  /// `ProjectFolderOps`). Null when the root came from a typed path/recent, or
  /// on platforms without bookmarks.
  final String? workspaceBookmark;

  /// MCP servers the agent may call, namespaced `mcp/<name>:tool/<tool>`.
  final List<McpServerConfig> mcpServers;

  /// Where `SKILL.md` skill folders live. Null means `<support>/skills`.
  final String? skillsRoot;

  /// Folders offered back in the picker, most recent first, deduped.
  final List<String> recentWorkspaces;

  // ---- Appearance / behaviour preferences (ADR-0005; ADR-0022 removed the
  // four that no code ever read back) --------------------------------------

  final AppFontSize fontSize;
  final AppConversationWidth conversationWidth;

  /// Whether a newly-shown tool block starts expanded (starkins default on).
  final bool expandToolCalls;

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
    AppFontSize? fontSize,
    AppConversationWidth? conversationWidth,
    bool? expandToolCalls,
  }) => AppSettings(
    model: model ?? this.model,
    workspaceRoot: workspaceRoot ?? this.workspaceRoot,
    workspaceBookmark: workspaceBookmark ?? this.workspaceBookmark,
    mcpServers: mcpServers ?? this.mcpServers,
    skillsRoot: skillsRoot ?? this.skillsRoot,
    theme: theme ?? this.theme,
    locale: locale ?? this.locale,
    recentWorkspaces: recentWorkspaces ?? this.recentWorkspaces,
    fontSize: fontSize ?? this.fontSize,
    conversationWidth: conversationWidth ?? this.conversationWidth,
    expandToolCalls: expandToolCalls ?? this.expandToolCalls,
  );

  /// Explicit: an empty path field means "take the permission back". The
  /// appearance prefs must survive, so every field is re-passed here.
  AppSettings withoutWorkspace() => AppSettings(
    model: model,
    mcpServers: mcpServers,
    skillsRoot: skillsRoot,
    theme: theme,
    locale: locale,
    recentWorkspaces: recentWorkspaces,
    fontSize: fontSize,
    conversationWidth: conversationWidth,
    expandToolCalls: expandToolCalls,
  );

  /// [path] adopted as the workspace, moved to the front of the recent list in
  /// one write. The bookmark is the pick's own (null clears any previous).
  AppSettings withWorkspace(String path, {String? bookmark}) => AppSettings(
    model: model,
    workspaceRoot: path,
    workspaceBookmark: bookmark,
    mcpServers: mcpServers,
    skillsRoot: skillsRoot,
    theme: theme,
    locale: locale,
    recentWorkspaces: _pushRecent(recentWorkspaces, path),
    fontSize: fontSize,
    conversationWidth: conversationWidth,
    expandToolCalls: expandToolCalls,
  );

  AppSettings forgetWorkspace(String path) => copyWith(
    recentWorkspaces: [
      for (final other in recentWorkspaces)
        if (other != path) other,
    ],
  );

  /// Whether the runtime built from [previous] has to be torn down. The
  /// appearance prefs never rebuild it — none of them touch the model, the MCP
  /// set, or the skills directory.
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
    // Persisted only when off the default, so a fresh document stays lean and
    // absent keys mean "default" on the read side.
    if (fontSize != AppFontSize.medium) 'fontSize': fontSize.name,
    if (conversationWidth != AppConversationWidth.normal)
      'conversationWidth': conversationWidth.name,
    if (!expandToolCalls) 'expandToolCalls': false,
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
      _listEq(other.recentWorkspaces, recentWorkspaces) &&
      other.fontSize == fontSize &&
      other.conversationWidth == conversationWidth &&
      other.expandToolCalls == expandToolCalls;

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
    fontSize,
    conversationWidth,
    expandToolCalls,
  );

  static bool _listEq<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
