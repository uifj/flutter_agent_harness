// Which top-level workspace the user is in (ADR-0007).
//
// The app grew a second face: 代理 (agent) — the conversation harness this app
// has always been — and 企划 (plan) — the markdown vault over the current
// workspace, with its extension panels (board / calendar / table). This
// controller is the one switch both share; it is view state, the same category
// as `LayoutController`'s column opens, and deliberately NOT persisted — a
// relaunch starts in the agent workspace, as starkins's tab provider does.
//
// A ChangeNotifier (not a riverpod Notifier) because riverpod imports are
// confined to `main.dart` + `app_providers.dart` (the ADR-0002 boundary); the
// provider in `app_providers.dart` fronts this controller like every other
// per-controller one.

import 'package:flutter/foundation.dart';

/// The top-level workspace. Order matters only for docs: `agent` is the default
/// and what a fresh launch lands in.
enum WorkspaceMode {
  agent,
  plan;

  String get name => switch (this) {
    agent => 'agent',
    plan => 'plan',
  };
}

/// The plan workspace's extension panels (ADR-0007 D4). `none` is the document
/// view — the vault tree + editor. These live only inside [WorkspaceMode.plan];
/// selecting `agent` resets to [PlanExtensionView.none], the same reset
/// semantics starkins's `_switchTab` applies to the other tab's pages.
enum PlanExtensionView {
  none,
  board,
  calendar,
  table;

  String get name => switch (this) {
    none => 'none',
    board => 'board',
    calendar => 'calendar',
    table => 'table',
  };
}

/// Owns the current [WorkspaceMode] and the plan workspace's open
/// [PlanExtensionView].
class WorkspaceModeController extends ChangeNotifier {
  WorkspaceMode _mode = WorkspaceMode.agent;
  PlanExtensionView _extension = PlanExtensionView.none;

  WorkspaceMode get mode => _mode;

  /// The plan workspace's active view. Meaningful only in [WorkspaceMode.plan].
  PlanExtensionView get extensionView => _extension;

  /// Switches the top-level workspace. Leaving 企划 closes its extension panel
  /// (starkins resets the other tab's pages on switch); entering 企划 always
  /// starts at the document view — the tree, not a stale panel.
  void selectMode(WorkspaceMode mode) {
    if (mode == _mode && _extension == PlanExtensionView.none) return;
    final changed = mode != _mode;
    _mode = mode;
    _extension = PlanExtensionView.none;
    if (changed || _extension != PlanExtensionView.none) notifyListeners();
  }

  /// Opens a plan extension panel (and enters 企划 if not there). Opening the
  /// panel that is already open closes it — the extension group's row is its
  /// own toggle, the same affordance starkins's nav rows carry.
  void toggleExtension(PlanExtensionView view) {
    if (view == PlanExtensionView.none) return;
    if (_mode == WorkspaceMode.plan && _extension == view) {
      _extension = PlanExtensionView.none;
    } else {
      _mode = WorkspaceMode.plan;
      _extension = view;
    }
    notifyListeners();
  }
}
