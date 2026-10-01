// Which top-level workspace the user is in (ADR-0007, revised 2026-10-01).
//
// The app grew a second face: 代理 (agent) — the conversation harness this app
// has always been — and 企划 (plan) — the document vault over the current
// workspace plus the plan collections as data views (ADR-0037). This
// controller is the one switch both share; it is view state, the same category
// as `LayoutController`'s column opens, and deliberately NOT persisted — a
// relaunch starts in the agent workspace, as starkins's tab provider does.
//
// The old hard-coded extension panels (board / calendar / table over
// `PlanTaskStore`) retired on 2026-10-01 by user decision: the extension area
// lists the plan collections, and the calendar capability lives inside a
// collection's Calendar view. `PlanExtensionView` therefore answers one
// question only — is a collection panel up.
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

/// What the plan workspace's center pane shows. `none` is the document view —
/// the vault tree + editor; `collection` is one plan collection's data view,
/// identified by [WorkspaceModeController.openCollectionId]. These live only
/// inside [WorkspaceMode.plan]; selecting `agent` resets to
/// [PlanExtensionView.none], the same reset semantics starkins's `_switchTab`
/// applies to the other tab's pages.
enum PlanExtensionView {
  none,

  /// One plan collection shown as an Anytype-shaped data view (ADR-0037 P3).
  collection;

  String get name => switch (this) {
    none => 'none',
    collection => 'collection',
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

  /// The collection the [PlanExtensionView.collection] panel is showing.
  String? get openCollectionId => _openCollectionId;
  String? _openCollectionId;

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

  /// Opens one plan collection as a data view (and enters 企划 if not there).
  /// Re-selecting the collection that is already up closes the panel — the
  /// extension row is its own toggle, the same affordance starkins's nav rows
  /// carry.
  void openCollection(String collectionId) {
    if (_mode == WorkspaceMode.plan &&
        _extension == PlanExtensionView.collection &&
        _openCollectionId == collectionId) {
      _extension = PlanExtensionView.none;
      _openCollectionId = null;
      notifyListeners();
      return;
    }
    _mode = WorkspaceMode.plan;
    _extension = PlanExtensionView.collection;
    _openCollectionId = collectionId;
    notifyListeners();
  }
}
