// The session list.
//
// The snapshot store has no listing API, so `AgentRuntime.listSessions` walks the
// pointer files it writes. That is disk work, hence the async refresh and the
// loading flag; the sidebar renders whatever the last successful scan produced.

import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../model/conversation.dart';
import '../model/turn_source.dart';

class SessionIndex extends ChangeNotifier {
  SessionIndex(this._runtime);

  TurnSource _runtime;

  final List<SessionSummary> _sessions = [];
  String? _activeId;
  bool _isLoading = false;
  String? _errorMessage;

  /// Newest first, as the runtime returns them.
  List<SessionSummary> get sessions => UnmodifiableListView(_sessions);

  /// The session the transcript is currently showing, or null for an unsaved new
  /// conversation.
  String? get activeId => _activeId;

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
        ..addAll(found);
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

  /// Swaps in a runtime rebuilt for new model settings. The store directory does
  /// not change with settings, so the list survives; it is re-scanned anyway in
  /// case the swap took a while.
  Future<void> adoptRuntime(TurnSource next) {
    _runtime = next;
    return refresh();
  }
}
