// The workspace escape guard: the app's one security boundary.
//
// It lives in `lib/model/` rather than next to the tools that were its first
// caller, because it now has two. The file tools hand resolved paths to the
// model; the workbench's explorer, editor and git views hand them to the user.
// Both need the same answer to "is this path inside the folder the user opened",
// and the second group must not import `package:genkit` to ask — see the header
// of `lib/genkit/agent_runtime.dart` for why that import is fenced.
//
// Nothing here is Flutter-aware, so it is testable without a widget binding, and
// `test/workspace_test.dart` exercises it directly rather than through a tool
// call.

import 'dart:io';

import 'package:path/path.dart' as p;

/// Raised by the path guard.
///
/// Never escapes a tool: it is caught and returned to the model as a failure so
/// it can correct itself, rather than killing the turn. UI callers surface it as
/// a message in the panel that asked.
class WorkspaceDenied implements Exception {
  WorkspaceDenied(this.message);

  final String message;

  @override
  String toString() => 'WorkspaceDenied: $message';
}

/// The directory the app is confined to.
///
/// Anything outside it is refused. The check resolves symlinks first, because a
/// symlink inside the root pointing out of it would otherwise pass a plain
/// prefix comparison.
class Workspace {
  Workspace._(this.root);

  /// Canonicalises [path] once, up front, so every later comparison is against a
  /// real path.
  static Workspace of(String path) =>
      Workspace._(Directory(path).absolute.resolveSymbolicLinksSync());

  /// The canonical absolute root.
  final String root;

  /// Resolves [raw] — relative to [root], or absolute — and refuses anything
  /// that lands outside.
  String resolve(String raw) {
    if (raw.trim().isEmpty) throw WorkspaceDenied('Empty path.');
    final joined = p.isAbsolute(raw) ? raw : p.join(root, raw);
    final real = _realise(p.normalize(joined));
    if (real != root && !p.isWithin(root, real)) {
      throw WorkspaceDenied(
        'Path is outside the workspace: $raw. The workspace root is $root.',
      );
    }
    return real;
  }

  /// [resolve] without the throw: null for anything refused.
  ///
  /// The UI asks this question about paths it did not choose — a git status line,
  /// a persisted tab from a session whose workspace has since moved — where a
  /// refusal is an ordinary outcome and a thrown exception would have to be
  /// caught at every call site to say the same thing.
  String? tryResolve(String raw) {
    try {
      return resolve(raw);
    } on WorkspaceDenied {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  /// [path] rendered relative to [root], for display and for tool results.
  ///
  /// The root itself renders as `.` rather than the empty string that
  /// `p.relative` would give, so a label is never blank.
  String relative(String path) {
    final rel = p.relative(path, from: root);
    return rel == '.' || rel.isEmpty ? '.' : rel;
  }

  /// Symlink-resolves as much of [absolute] as exists, then re-appends the tail
  /// that does not. A file about to be created has no real path of its own, but
  /// its parent chain does — and that is where an escaping symlink would sit.
  String _realise(String absolute) {
    final missing = <String>[];
    var probe = absolute;
    while (true) {
      if (Directory(probe).existsSync() || File(probe).existsSync()) {
        final real = probe == absolute
            ? _resolveLinks(probe)
            : p.joinAll([_resolveLinks(probe), ...missing.reversed]);
        return p.normalize(real);
      }
      final parent = p.dirname(probe);
      if (parent == probe) return absolute; // Hit the filesystem root.
      missing.add(p.basename(probe));
      probe = parent;
    }
  }

  String _resolveLinks(String path) {
    try {
      return Directory(path).existsSync()
          ? Directory(path).resolveSymbolicLinksSync()
          : File(path).resolveSymbolicLinksSync();
    } on FileSystemException {
      return path;
    }
  }
}
