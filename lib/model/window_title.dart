// The title bar is the one piece of chrome this app does not draw: macOS puts
// the bundle name there, which is the same two words the sidebar's brand row
// already shows about 40px below it (ADR-0019). Making that line say what the
// window is *about* — the conversation and the folder it works in — is the fix
// that needs no new OS surface.
//
// Pure Dart because the rule is what can be tested; the imperative call stays
// in `state/window_title_service.dart`.

import 'package:path/path.dart' as p;

/// The conversation's own words can be long, and a title bar truncates with
/// *its* ellipsis — which would drop the folder, the half the user cannot
/// guess. So the sentence yields first, at a third of the budget.
const _maxSessionChars = 48;

/// `"<conversation> — <folder>"`, or whichever half exists. Null when neither
/// does, which means "leave whatever the system already shows": a window with
/// no workspace and no saved conversation is a fresh one, and the bundle name
/// is the honest thing to read there.
String? composeWindowTitle({String? sessionTitle, String? workspaceRoot}) {
  final folder = (workspaceRoot == null || workspaceRoot.isEmpty)
      ? null
      : p.basename(p.normalize(p.absolute(workspaceRoot)));
  var session = sessionTitle?.trim();
  if (session != null && session.isEmpty) session = null;
  if (session != null && session.length > _maxSessionChars) {
    session = '${session.substring(0, _maxSessionChars - 1)}…';
  }
  if (session != null && folder != null) return '$session — $folder';
  return session ?? folder;
}
