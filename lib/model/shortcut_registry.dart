// The shortcut registry (ADR-0045 PC): one place defines the app's commands
// and their default bindings, and three surfaces read it — the hotkey service
// (which parses bindings into key events), the tray menu, and the settings
// page's read-only table. ZCode keeps the same single-source shape
// (`shortcutCommands.ts:61-100`: id / channel / scope / defaultBindings);
// recording and conflict detection are a later batch.

/// A binding as a platform-neutral string: `CmdOrCtrl+Shift+H`. `CmdOrCtrl`
/// means meta on macOS and control elsewhere, resolved by the parser.
class ShortcutBinding {
  const ShortcutBinding(this.spec);

  final String spec;

  /// The modifiers, in canonical order, without the key.
  List<String> get modifiers =>
      spec.split('+').take(spec.split('+').length - 1).toList();

  /// The trailing key token, e.g. `H`, `N`, `Comma`.
  String get key => spec.split('+').last;
}

class ShortcutCommand {
  const ShortcutCommand({
    required this.id,
    required this.labelKey,
    required this.defaultSpec,
    required this.system,
  });

  /// Stable id — persistence and lookup key.
  final String id;

  /// The i18n key the settings table renders.
  final String labelKey;

  /// The platform-neutral default binding.
  final String defaultSpec;

  /// True = system scope (works while the app is backgrounded, via
  /// hotkey_manager's system registration); false = in-app only.
  final bool system;

  ShortcutBinding get binding => ShortcutBinding(defaultSpec);
}

abstract final class ShortcutRegistry {
  /// CmdOrCtrl resolves per platform: the registry is data, the parser and
  /// the tooltip renderer pick the platform's spelling.
  static const String tooltipAcceleratorMac = '\u2318';

  /// The commands, in the order the settings table lists them.
  static const List<ShortcutCommand> commands = [
    ShortcutCommand(
      id: 'toggleWindow',
      labelKey: 'shortcutToggleWindow',
      defaultSpec: 'CmdOrCtrl+Shift+H',
      system: true,
    ),
    ShortcutCommand(
      id: 'newSession',
      labelKey: 'shortcutNewSession',
      defaultSpec: 'CmdOrCtrl+N',
      system: false,
    ),
    ShortcutCommand(
      id: 'openSettings',
      labelKey: 'shortcutOpenSettings',
      defaultSpec: 'CmdOrCtrl+Comma',
      system: false,
    ),
    ShortcutCommand(
      id: 'toggleSidebar',
      labelKey: 'shortcutToggleSidebar',
      defaultSpec: 'CmdOrCtrl+B',
      system: false,
    ),
  ];

  static ShortcutCommand? byId(String id) {
    for (final command in commands) {
      if (command.id == id) return command;
    }
    return null;
  }

  /// The human-facing accelerator spelling for the current platform — the
  /// tooltip text (the settings table renders the raw spec through the same
  /// helper with macOS's glyphs).
  static String acceleratorFor(String spec, {required bool isMacOS}) {
    // macOS spells the modifier as a bare glyph — the '+' after CmdOrCtrl
    // must go with the word, or the glyph reads as a key of its own.
    return isMacOS
        ? spec.replaceAll('CmdOrCtrl+', '\u2318')
        : spec.replaceAll('CmdOrCtrl+', 'Ctrl+');
  }
}
