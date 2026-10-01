// The history list's grouping, as a pure function (ADR-0039 D2).
//
// The reference implementation answers this on the query side — a sqlite index
// keyed by `(workspace_key, task_id)` with covering indexes per workspace
// (`_archive_project/ZCode-main/packages/services/src/tasksDatabase/schema-v1.ts:4-32`)
// — because it can hold thousands of tasks on one machine. This app has one
// folder of pointer files, so the honest place for the rule is here: no IO, no
// clock, no locale. A list goes in, ordered groups come out, and the ordering
// is testable without a disk.
//
// Three rules, each with a reason:
//   * inside a group, pinned rows first (newest pin first), then `updatedAt`
//     descending — the reference's `ORDER BY updated_at DESC` plus its pin
//     section;
//   * the current workspace leads, then groups by their newest row, so the
//     folder you are working in does not slide down the list as you read it;
//   * a session with no recorded workspace gets its own trailing group. The
//     reference has no such bucket because it never had a session without one;
//     ours does — everything written before ADR-0039. Folding those into a real
//     folder would invent a fact, and dropping them would lose history.

import 'package:path/path.dart' as p;

import 'conversation.dart';

/// One workspace's slice of the history, in display order.
class WorkspaceGroup {
  const WorkspaceGroup({
    required this.key,
    required this.workspaceRoot,
    required this.sessions,
  });

  /// [workspaceKey] of [workspaceRoot]. Collapse state is stored against this,
  /// so a folder does not come back expanded because the other spelling of it
  /// was collapsed.
  final String key;

  /// The path as recorded, used for display and for anything that touches disk.
  /// Null for the unassigned bucket.
  final String? workspaceRoot;

  /// Pinned first, then newest — the order the row builder walks.
  final List<SessionSummary> sessions;

  bool get isUnassigned => workspaceRoot == null;

  /// The folder's leaf name. The unassigned bucket has none, so the surface
  /// supplies its own label there: it is copy, not a path.
  String get displayName =>
      workspaceRoot == null ? '' : p.basename(p.normalize(workspaceRoot!));

  DateTime get newest => sessions.first.updatedAt;
}

/// Groups [sessions] by the folder they happened in; [currentWorkspace] leads
/// the list when it is among them. The input list is never mutated.
List<WorkspaceGroup> groupSessionsByWorkspace({
  required List<SessionSummary> sessions,
  String? currentWorkspace,
}) {
  final byKey = <String, List<SessionSummary>>{};
  for (final session in sessions) {
    final root = session.workspaceRoot;
    final key = root == null ? unassignedKey : workspaceKey(root);
    (byKey[key] ??= <SessionSummary>[]).add(session);
  }

  final groups = <WorkspaceGroup>[];
  byKey.forEach((key, members) {
    members.sort(_byPinThenRecency);
    groups.add(
      WorkspaceGroup(
        key: key,
        workspaceRoot: members.first.workspaceRoot,
        sessions: members,
      ),
    );
  });

  groups.sort((a, b) {
    if (a.isUnassigned != b.isUnassigned) return a.isUnassigned ? 1 : -1;
    if (a.isUnassigned) return 0;
    final aIsCurrent = a.key == workspaceKey(currentWorkspace ?? '');
    final bIsCurrent = b.key == workspaceKey(currentWorkspace ?? '');
    if (aIsCurrent != bIsCurrent) return aIsCurrent ? -1 : 1;
    return b.newest.compareTo(a.newest);
  });
  return groups;
}

/// The bucket for sessions that predate ADR-0039 and so name no folder.
const unassignedKey = '';

/// The key two spellings of the same folder collapse to.
///
/// On macOS `/var`, `/etc` and `/tmp` are symlinks onto `/private/…`, so a path
/// read back from the system temp folder and the same path kept in the settings
/// document differ by that prefix. That divergence is what
/// `test/app_scope_test.dart` fails on today; grouping by the raw string would
/// show the user two folders for one project.
String workspaceKey(String path) {
  if (path.isEmpty) return unassignedKey;
  var normalized = p.normalize(path);
  const privatePrefix = '/private/';
  if (normalized.startsWith(privatePrefix)) {
    normalized = '/${normalized.substring(privatePrefix.length)}';
  }
  return normalized;
}

int _byPinThenRecency(SessionSummary a, SessionSummary b) {
  if ((a.pinnedAt == null) != (b.pinnedAt == null)) {
    return a.pinnedAt == null ? 1 : -1;
  }
  final pin = (b.pinnedAt ?? DateTime(0)).compareTo(a.pinnedAt ?? DateTime(0));
  return pin != 0 ? pin : b.updatedAt.compareTo(a.updatedAt);
}
