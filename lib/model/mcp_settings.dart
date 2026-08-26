// One MCP server entry, as the settings screen edits it and the runtime dials it.
//
// Mirrors dsh's `mcp` capability config (a named server reachable over stdio or
// HTTP); the runtime turns each entry into one namespaced client
// `mcp/<name>:tool/<tool>` inside `genkit_mcp`'s host. Corruption costs one
// entry, not the whole list — the same repair-not-reject contract as
// `sidebar_tab.dart`.

/// A server the agent may call through the `mcp/<name>:tool/<tool>` namespace.
///
/// Exactly one of [command] (with optional [args], stdio) or [url]
/// (Streamable HTTP) is set; a config with neither is dropped at parse time.
class McpServerConfig {
  const McpServerConfig({
    required this.name,
    this.command,
    this.args = const [],
    this.url,
  }) : assert(
         command != null || url != null,
         'stdio command or http url is required',
       );

  /// Namespace key. Also the prefix of every tool this server contributes.
  final String name;

  /// Executable to launch over stdio, e.g. `npx`.
  final String? command;

  /// Arguments for [command].
  final List<String> args;

  /// Remote MCP endpoint (Streamable HTTP).
  final String? url;

  bool get isStdio => command != null;

  Map<String, Object?> toJson() => {
    'name': name,
    if (command != null) 'command': command,
    if (args.isNotEmpty) 'args': args,
    if (url != null) 'url': url,
  };

  /// Null when [raw] is not a usable entry, so one bad row costs one row.
  static McpServerConfig? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final name = raw['name'];
    if (name is! String || name.trim().isEmpty) return null;
    final command = raw['command'] as String?;
    final url = raw['url'] as String?;
    if (command == null && url == null) return null;
    final args = switch (raw['args']) {
      final List rawArgs => [
        for (final arg in rawArgs)
          if (arg is String) arg,
      ],
      _ => const <String>[],
    };
    return McpServerConfig(
      name: name.trim(),
      command: command,
      args: args,
      url: url,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is McpServerConfig &&
      other.name == name &&
      other.command == command &&
      other.url == url &&
      _listEq(other.args, args);

  @override
  int get hashCode => Object.hash(name, command, url, Object.hashAll(args));

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
