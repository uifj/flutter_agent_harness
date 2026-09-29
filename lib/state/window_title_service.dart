// The window title is not a widget: the system paints it, so the only way to
// change it is an imperative call on `window_manager` — the same seam the tray
// and the global hotkeys already use. It is initialized in `main` after the
// first frame, when the window handle exists.
//
// One truth per string: the conversation's name is the sidebar's
// `SessionSummary.title`, and the workspace is the settings document's
// `workspaceRoot`. Recomposing either here would be a second place to be wrong.

import 'package:window_manager/window_manager.dart';

import '../model/window_title.dart';
import 'session_index.dart';

class WindowTitleService {
  WindowTitleService({required this.sessions});

  /// The list the sidebar renders: it knows which session is active, and its
  /// title is what the row already shows the user.
  final SessionIndex sessions;

  String? _workspaceRoot;

  void init() {
    sessions.addListener(_publish);
    _publish();
  }

  void dispose() => sessions.removeListener(_publish);

  /// Called when the settings document's workspace moves. The document is not
  /// a `Listenable`, so `main` pushes it — the same way the tray's label is
  /// pushed rather than polled.
  void setWorkspace(String? root) {
    if (_workspaceRoot == root) return;
    _workspaceRoot = root;
    _publish();
  }

  Future<void> _publish() async {
    final active = sessions.activeId;
    String? sessionTitle;
    if (active != null) {
      for (final session in sessions.sessions) {
        if (session.id == active) sessionTitle = session.title;
      }
    }
    final title = composeWindowTitle(
      sessionTitle: sessionTitle,
      workspaceRoot: _workspaceRoot,
    );
    if (title != null) await windowManager.setTitle(title);
  }
}
