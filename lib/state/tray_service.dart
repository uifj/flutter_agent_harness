// System tray integration.
//
// Shows a tray icon with a context menu (show/hide window, quit) and listens
// for icon clicks to toggle window visibility. The service is initialized once
// in main after the window is shown.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// The app's system tray service. Manages the tray icon, context menu, and
/// click-to-toggle-window behaviour.
class TrayService with TrayListener {
  TrayService({required this.onQuit});

  /// Called when the user selects "Quit" from the tray menu.
  final VoidCallback onQuit;

  Future<void> init() async {
    // The icon path is relative to flutter_assets (declared in pubspec assets).
    const iconPath = 'assets/icon/app_icon_source.png';
    await trayManager.setIcon(iconPath, isTemplate: Platform.isMacOS);
    await trayManager.setToolTip('Agent Harness');

    final menu = Menu(
      items: [
        MenuItem(label: 'Show / Hide', onClick: (_) => _toggleWindow()),
        MenuItem.separator(),
        MenuItem(label: 'Quit', onClick: (_) => onQuit()),
      ],
    );
    await trayManager.setContextMenu(menu);
    trayManager.addListener(this);
  }

  Future<void> _toggleWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  @override
  void onTrayIconMouseUp() {
    // Left-click on the tray icon: toggle window visibility directly.
    _toggleWindow();
  }

  @override
  void onTrayIconRightMouseUp() {
    // Right-click: show the context menu.
    trayManager.popUpContextMenu();
  }

  Future<void> dispose() async {
    trayManager.removeListener(this);
    await trayManager.destroy();
  }
}
