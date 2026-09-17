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

/// The app's global hotkey service. Registers a fixed set of hotkeys and
/// exposes callbacks the shell wires to its actions.
class HotkeyService {
  HotkeyService({
    required this.onToggleWindow,
    required this.onNewSession,
    required this.onOpenSettings,
  });

  /// Toggles the window's visibility (show/hide).
  final VoidCallback onToggleWindow;

  /// Starts a new conversation session.
  final VoidCallback onNewSession;

  /// Opens the settings page.
  final VoidCallback onOpenSettings;

  final List<HotKey> _registered = [];

  /// Registers all hotkeys. Call once after the window is shown.
  Future<void> init() async {
    await hotKeyManager.unregisterAll();
    _registered.clear();

    final isMac = Platform.isMacOS;
    final mod = isMac ? HotKeyModifier.meta : HotKeyModifier.control;

    // System-scope: works even when the app is backgrounded.
    await _register(
      HotKey(
        key: LogicalKeyboardKey.keyH,
        modifiers: [mod, HotKeyModifier.shift],
        scope: HotKeyScope.system,
      ),
      onKeyDown: (_) => onToggleWindow(),
    );

    // In-app scope: only fires when the app has focus.
    await _register(
      HotKey(
        key: LogicalKeyboardKey.keyN,
        modifiers: [mod],
        scope: HotKeyScope.inapp,
      ),
      onKeyDown: (_) => onNewSession(),
    );

    await _register(
      HotKey(
        key: LogicalKeyboardKey.comma,
        modifiers: [mod],
        scope: HotKeyScope.inapp,
      ),
      onKeyDown: (_) => onOpenSettings(),
    );
  }

  Future<void> _register(
    HotKey key, {
    required HotKeyHandler onKeyDown,
  }) async {
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
