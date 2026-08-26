// Everything the app remembers between launches.
//
// Three halves kept in one document because they are saved by one screen: the
// model connection, the workspace folder, and the agent's extension surface
// (MCP servers, skills directory). They differ in what a change costs — the
// model fields and the extension surface are baked into a runtime and need a
// new one, the workspace is a live setter — so they stay separate fields rather
// than being flattened.

import 'mcp_settings.dart';
import 'model_settings.dart';

class AppSettings {
  const AppSettings({
    this.model = const ModelSettings(),
    this.workspaceRoot,
    this.mcpServers = const [],
    this.skillsRoot,
  });

  AppSettings.fromJson(Map<String, dynamic> json)
    : model = ModelSettings.fromJson(
        json['model'] as Map<String, dynamic>? ?? const {},
      ),
      workspaceRoot = json['workspaceRoot'] as String?,
      mcpServers = [
        for (final entry in (json['mcpServers'] as List? ?? const []))
          ?McpServerConfig.fromJson(entry),
      ],
      skillsRoot = json['skillsRoot'] as String?;

  final ModelSettings model;

  /// The folder the file and shell tools are confined to. Null means they refuse
  /// every call, which is the state a fresh install is in — there is
  /// no defensible default, since the app cannot guess which folder the user
  /// meant to expose.
  final String? workspaceRoot;

  /// MCP servers the agent may call, namespaced `mcp/<name>:tool/<tool>`.
  final List<McpServerConfig> mcpServers;

  /// Where `SKILL.md` skill folders live. Null means the default
  /// `<support>/skills`, which is what the runtime is handed when the user has
  /// not chosen one.
  final String? skillsRoot;

  AppSettings copyWith({
    ModelSettings? model,
    String? workspaceRoot,
    List<McpServerConfig>? mcpServers,
    String? skillsRoot,
  }) => AppSettings(
    model: model ?? this.model,
    workspaceRoot: workspaceRoot ?? this.workspaceRoot,
    mcpServers: mcpServers ?? this.mcpServers,
    skillsRoot: skillsRoot ?? this.skillsRoot,
  );

  /// Explicit, because [copyWith] cannot express it: an empty path field means
  /// "take the permission back", not "leave it alone".
  AppSettings withoutWorkspace() => AppSettings(
    model: model,
    mcpServers: mcpServers,
    skillsRoot: skillsRoot,
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
    if (mcpServers.isNotEmpty)
      'mcpServers': [for (final server in mcpServers) server.toJson()],
    if (skillsRoot != null) 'skillsRoot': skillsRoot,
  };

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.model == model &&
      other.workspaceRoot == workspaceRoot &&
      _listEq(other.mcpServers, mcpServers) &&
      other.skillsRoot == skillsRoot;

  @override
  int get hashCode => Object.hash(
    model,
    workspaceRoot,
    Object.hashAll(mcpServers),
    skillsRoot,
  );

  /// Lists have no deep `==` of their own — a fresh `[]` is not `const []` —
  /// so equality here has to walk the elements. `McpServerConfig` itself has a
  /// proper `==`, which is what makes the walk meaningful.
  static bool _listEq(List<McpServerConfig> a, List<McpServerConfig> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
