// The session list.
//
// The snapshot store has no listing API, so `AgentRuntime.listSessions` walks the
// pointer files it writes. That is disk work, hence the async refresh and the
// loading flag; the sidebar renders whatever the last successful scan produced.

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../model/conversation.dart';
import '../model/turn_source.dart';
import 'session_registry.dart';

/// The listable sessions, decorated with the app's own metadata.
///
/// The runtime answers "which sessions exist"; [SessionRegistry] answers "which
/// folder, pinned?, renamed?, deleted?". The composition happens here and
/// nowhere else, so a surface cannot see a deleted row, a stale title, or two
/// candidate titles (ADR-0039).
class SessionIndex extends ChangeNotifier {
  SessionIndex(this._runtime, {SessionRegistry? registry})
    : _registry = registry;

  TurnSource _runtime;
  final SessionRegistry? _registry;

  final List<SessionSummary> _sessions = [];
  String? _activeId;
  bool _isLoading = false;
  String? _errorMessage;

  /// Newest first, as the runtime returns them.
  List<SessionSummary> get sessions => UnmodifiableListView(_sessions);

  /// The session the transcript is currently showing, or null for an unsaved new
  /// conversation.
  String? get activeId => _activeId;

  /// The summary for [activeId], or null when the transcript is showing an
  /// unsaved new conversation — which is why the header's menu is optional.
  SessionSummary? get active {
    final id = _activeId;
    if (id == null) return null;
    for (final session in _sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  bool get isLoading => _isLoading;

  /// Set when the last scan threw. The previous list is kept: a transient disk
  /// error should not empty the sidebar.
  String? get errorMessage => _errorMessage;

  /// Re-scans the store.
  ///
  /// Concurrent calls are dropped rather than queued — a scan already in flight
  /// will see anything a second one would have.
  Future<void> refresh() async {
    if (_isLoading) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final found = await _runtime.listSessions();
      _sessions
        ..clear()
        ..addAll(_decorate(found));
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setActive(String? id) {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
  }

  /// Set when the sidecar could not be written. The list still answers from
  /// memory, so the user has to be told at the action that failed — a value
  /// with no reader is the defect class `settings_reach_test` exists for
  /// (ADR-0022), and a silent persistence failure is its worse twin.
  String? get metadataError => _registry?.errorMessage;

  /// Every folder any session was started in — the history's own half of the
  /// group list, which the surface unions with `AppSettings.recentWorkspaces`.
  Set<String> get knownWorkspaces => _registry?.knownWorkspaces ?? const {};

  /// The history's three mutations, and the only ones. They live here rather
  /// than at the call sites so the visible list and the sidecar can never
  /// disagree: a row that stays on screen after being deleted, or keeps its old
  /// title after a rename, is exactly the two-values failure ADR-0014 names.
  void setPinned(String sessionId, bool pinned) {
    _registry?.setPinned(sessionId, pinned, now: DateTime.now());
    _redecorate();
  }

  void rename(String sessionId, String title) {
    _registry?.rename(sessionId, title);
    _redecorate();
  }

  void remove(String sessionId) {
    _registry?.markDeleted(sessionId, now: DateTime.now());
    _sessions.removeWhere((session) => session.id == sessionId);
    notifyListeners();
  }

  /// Re-resolves the visible rows against the registry. Not a re-scan: a scan
  /// that happens to be in flight would otherwise be dropped by [refresh]'s
  /// guard and leave the row showing what it used to be called.
  void _redecorate() {
    for (var i = 0; i < _sessions.length; i++) {
      _sessions[i] = _decorateOne(_sessions[i]);
    }
    notifyListeners();
  }

  SessionSummary _decorateOne(SessionSummary session) {
    final registry = _registry;
    if (registry == null) return session;
    final meta = registry.metaOf(session.id);
    return SessionSummary(
      id: session.id,
      updatedAt: session.updatedAt,
      title: meta.title ?? session.title,
      // The registry is where the folder gets recorded, and today it is the
      // only source — but a summary that already carries one is not thrown
      // away for that. Discarding an input is how a field becomes a lie.
      workspaceRoot: meta.workspaceRoot ?? session.workspaceRoot,
      pinnedAt: meta.pinnedAt,
    );
  }

  List<SessionSummary> _decorate(List<SessionSummary> found) {
    final registry = _registry;
    if (registry == null) return found;
    return [
      for (final session in found)
        if (!registry.isDeleted(session.id)) _decorateOne(session),
    ];
  }

  /// Swaps in a runtime rebuilt for new model settings. The store directory does
  /// not change with settings, so the list survives; it is re-scanned anyway in
  /// case the swap took a while.
  Future<void> adoptRuntime(TurnSource next) {
    _runtime = next;
    return refresh();
  }
}
