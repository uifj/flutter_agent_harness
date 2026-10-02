// Global hotkey registration.
//
// Registers system-wide and in-app hotkeys for common actions. System-scope
// hotkeys work even when the app is not focused (e.g., show/hide window);
// in-app hotkeys only fire when the app has focus.
//
// The service is initialized once in main after the window is shown. Hotkeys
// are unregistered on dispose to avoid leaking platform resources.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import '../model/shortcut_registry.dart';

/// The app's global hotkey service. Registers a fixed set of hotkeys and
/// exposes callbacks the shell wires to its actions.
class HotkeyService {
  HotkeyService({
    required this.onToggleWindow,
    required this.onNewSession,
    required this.onOpenSettings,
    required this.onToggleSidebar,
  });

  /// Toggles the window's visibility (show/hide).
  final VoidCallback onToggleWindow;

  /// Starts a new conversation session.
  final VoidCallback onNewSession;

  /// Opens the settings page.
  final VoidCallback onOpenSettings;

  /// Collapses the sidebar to its rail, or asks for the panel back. The frame
  /// decides what "toggle" means at the current width — see
  /// `LayoutController.toggleSidebar`.
  final VoidCallback onToggleSidebar;

  /// The sidebar toggle's accelerator, spelled the way the host spells it. The
  /// tooltip shows this so the shortcut is discoverable rather than tribal
  /// knowledge; `lib/ui` cannot ask the platform directly (architecture rule 5).
  static String get sidebarAccelerator =>
      Platform.isMacOS ? '\u2318B' : 'Ctrl+B';

  final List<HotKey> _registered = [];

  /// Registers all hotkeys. Call once after the window is shown.
  Future<void> init() async {
    await hotKeyManager.unregisterAll();
    _registered.clear();

    final isMac = Platform.isMacOS;
    final mod = isMac ? HotKeyModifier.meta : HotKeyModifier.control;

    // The registry is the single definition (ADR-0045 PC); this service only
    // parses bindings into key events and wires the handlers by id.
    final handlers = <String, HotKeyHandler>{
      'toggleWindow': (_) => onToggleWindow(),
      'newSession': (_) => onNewSession(),
      'openSettings': (_) => onOpenSettings(),
      'toggleSidebar': (_) => onToggleSidebar(),
    };
    for (final command in ShortcutRegistry.commands) {
      final handler = handlers[command.id];
      if (handler == null) continue;
      final hotKey = _parse(command, mod);
      if (hotKey == null) continue;
      await _register(
        HotKey(
          key: hotKey,
          modifiers: _modifiersOf(command, mod),
          scope: command.system ? HotKeyScope.system : HotKeyScope.inapp,
        ),
        onKeyDown: handler,
      );
    }
  }

  /// The registry spec's trailing token as a key event key. Unknown tokens
  /// return null and the command is skipped — a registry entry that cannot be
  /// parsed must not silently bind to the wrong key.
  LogicalKeyboardKey? _parse(ShortcutCommand command, HotKeyModifier mod) =>
      switch (command.binding.key) {
        'H' => LogicalKeyboardKey.keyH,
        'N' => LogicalKeyboardKey.keyN,
        'Comma' => LogicalKeyboardKey.comma,
        'B' => LogicalKeyboardKey.keyB,
        _ => null,
      };

  List<HotKeyModifier> _modifiersOf(
    ShortcutCommand command,
    HotKeyModifier mod,
  ) {
    final modifiers = <HotKeyModifier>[];
    for (final modifier in command.binding.modifiers) {
      switch (modifier) {
        case 'CmdOrCtrl':
          modifiers.add(mod);
        case 'Shift':
          modifiers.add(HotKeyModifier.shift);
        case 'Alt':
          modifiers.add(HotKeyModifier.alt);
      }
    }
    return modifiers;
  }

  Future<void> _register(HotKey key, {required HotKeyHandler onKeyDown}) async {
    try {
      await hotKeyManager.register(key, keyDownHandler: onKeyDown);
      _registered.add(key);
    } catch (_) {
      // Registration can fail if the hotkey is already taken by another app.
      // Silently skip — the user can still access the action via the UI.
    }
  }

  /// Unregisters all hotkeys. Call on app shutdown.
  Future<void> dispose() async {
    await hotKeyManager.unregisterAll();
    _registered.clear();
  }
}
