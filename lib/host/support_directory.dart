// One-time support-directory rename (企划星 identity change).
//
// path_provider keys the support directory by the application identity, so
// moving from `com.stow.agentHarness` to `top.planstar.desktop` silently
// relocates every file the app owns: settings.json, prefs.json, sessions/,
// workbench/, approvals.json, checkpoints/, usage/, logs/. A fresh empty
// directory is indistinguishable from "the user never configured anything",
// which is why this runs before anything reads the support root.
//
// Rename, not copy: two directories holding the same app state is exactly the
// two-truths failure this repo keeps legislating against. The copy path exists
// only for a cross-device rename, and leaves the legacy directory in place so a
// failed boot cannot destroy the only copy.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Identities this app's support files have lived under. Searched as siblings
/// of the current directory, which keeps this correct on each platform's own
/// idea of where support data goes.
const List<String> legacySupportNames = [
  'com.stow.agentHarness',
  'Agent Harness',
  'agent_harness',
];

/// Renames the first non-empty legacy sibling onto [current] when [current] has
/// nothing in it. Returns the legacy name it moved, or null when there was
/// nothing to do.
Future<String?> migrateSupportDirectory(Directory current) async {
  if (await _hasContents(current)) return null;
  final here = p.basename(current.path);
  for (final name in legacySupportNames) {
    if (name == here) return null;
    final legacy = Directory(p.join(p.dirname(current.path), name));
    if (!await _hasContents(legacy)) continue;
    try {
      if (await current.exists()) await current.delete();
      await legacy.rename(current.path);
      return name;
    } on FileSystemException {
      await _copyTree(legacy, current);
      return '$name (copied)';
    }
  }
  return null;
}

Future<bool> _hasContents(Directory d) async =>
    await d.exists() && await d.list().isEmpty == false;

Future<void> _copyTree(Directory from, Directory to) async {
  await to.create(recursive: true);
  await for (final e in from.list()) {
    final target = p.join(to.path, p.basename(e.path));
    if (e is Directory) {
      await _copyTree(e, Directory(target));
    } else if (e is File) {
      await e.copy(target);
    }
  }
}
