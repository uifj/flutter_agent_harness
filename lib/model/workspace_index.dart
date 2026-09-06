// The workspace file index behind the composer's `@` mention menu.
//
// A port of dsh-at-file's `files.ts` (FSMargoo/dsh-at-file): a breadth-first
// walk of the workspace that collects every file AND directory as an entry,
// skips the well-known ignore basenames, guards against symlink cycles by
// never re-entering a canonical ancestor, and stops honestly at the entry
// cap with a `truncated` flag rather than silently truncating.
//
// Differences from the plugin, forced by this app's shape:
//  * The walk is synchronous — it runs in a `compute`-style isolate from the
//    composer (see `indexWorkspace`'s callers), not streamed dirent by
//    dirent. A desktop workspace is small enough that one pass is fine, and
//    the cap bounds the worst case.
//  * Ignore rules are a fixed set, not settings: this build has no
//    per-profile ignore configuration to preserve.

import 'dart:io';

import 'package:path/path.dart' as p;

/// One indexed entry: a workspace-relative path and its kind. Directories are
/// indexed too, so a mention can reference a path without reading its
/// descendants — the plugin's existence-only contract.
class FileEntry {
  const FileEntry({required this.relative, required this.kind});

  /// Forward-slash path relative to the workspace root, stable across
  /// platforms.
  final String relative;

  /// `dir` or `file`.
  final String kind;

  @override
  bool operator ==(Object other) =>
      other is FileEntry && other.relative == relative && other.kind == kind;

  @override
  int get hashCode => Object.hash(relative, kind);
}

/// One index pass: the sorted entries plus the honest truncation flag.
class WorkspaceIndex {
  const WorkspaceIndex({required this.entries, required this.truncated});

  final List<FileEntry> entries;

  /// True when the walk hit [maxFiles] before the tree was exhausted. The
  /// menu shows this as a notice rather than presenting a partial list as
  /// the whole workspace.
  final bool truncated;
}

/// Directory basenames the walk skips — dsh-at-file's `DEFAULT_IGNORE_DIRS`:
/// version control, IDE metadata, dependency trees, caches, build output.
const defaultIgnoreDirs = <String>{
  '.git', '.hg', '.svn', '.idea', '.vs', '.vscode', '.fleet', '.history',
  '.metadata', '.settings', 'node_modules', 'bower_components', 'vendor',
  'Pods', '.gradle', '.kotlin', '.cxx', '.externalNativeBuild', '.dart_tool',
  '.swiftpm', '.build', '.cache', '.parcel-cache', '.turbo', '.nx',
  '__pycache__', '.pytest_cache', '.mypy_cache', '.ruff_cache', '.tox',
  '.venv', 'venv', '.next', '.nuxt', '.output', '.svelte-kit', '.angular',
  'build', 'bin', 'dist', 'out', 'target', 'obj', 'coverage', 'DerivedData',
  'xcuserdata', 'CMakeFiles', 'cmake-build-debug', 'cmake-build-release',
  'cmake-build-relwithdebinfo', 'cmake-build-minsizerel', '_deps', '.godot',
  'Library', 'Temp', 'Logs', 'Binaries', 'Intermediate', 'Saved',
  'DerivedDataCache',
};

/// File basenames the walk skips — the OS metadata trio.
const defaultIgnoreFiles = <String>{'desktop.ini', 'Thumbs.db', '.DS_Store'};

/// Hard cap on collected entries, the plugin's default scale.
const defaultMaxEntries = 5000;

/// Collects every file and directory under [root], bounded by [maxEntries].
///
/// The walk resolves the root canonically first (the temp-directory symlink
/// on macOS is the standing example of why), then proceeds breadth-first so
/// shallow paths enter the index before deep ones — the picker's browse mode
/// presents them in that order for free.
WorkspaceIndex indexWorkspace(
  String root, {
  int maxEntries = defaultMaxEntries,
  Set<String> ignoreDirs = defaultIgnoreDirs,
  Set<String> ignoreFiles = defaultIgnoreFiles,
}) {
  final entries = <FileEntry>[];
  var truncated = false;

  final String rootPath;
  try {
    rootPath = Directory(root).resolveSymbolicLinksSync();
  } on FileSystemException {
    return const WorkspaceIndex(entries: [], truncated: false);
  }

  // Canonical paths already present above a queued directory: a link may
  // point to itself or any parent, and re-entering one is an infinite walk.
  final queue = <(String, String, Set<String>)>[
    (rootPath, rootPath, <String>{}),
  ];
  // [children] is built per task below.

  while (queue.isNotEmpty) {
    final (dir, canonical, ancestors) = queue.removeAt(0);
    if (ancestors.contains(canonical)) continue;
    final childAncestors = <String>{...ancestors, canonical};

    final List<FileSystemEntity> listing;
    try {
      listing = Directory(dir).listSync(followLinks: false);
    } on FileSystemException {
      // Unreadable directory: the walk continues without it, the way the
      // plugin's console.warn-and-continue does.
      continue;
    }

    for (final entity in listing) {
      if (entries.length >= maxEntries) {
        truncated = true;
        break;
      }
      final name = p.basename(entity.path);
      // With `followLinks: false` — the default resolves the link's TARGET,
      // which would hide every link from the branch below.
      final isLink = FileSystemEntity.typeSync(entity.path, followLinks: false) ==
          FileSystemEntityType.link;

      // A link's kind rides its target: a broken or inaccessible link is
      // skipped rather than poisoning the pass.
      String kind;
      if (isLink) {
        try {
          final target = Link(entity.path).resolveSymbolicLinksSync();
          final type = FileSystemEntity.typeSync(target);
          if (type == FileSystemEntityType.directory) {
            kind = 'dir';
          } else if (type == FileSystemEntityType.file) {
            kind = 'file';
          } else {
            continue;
          }
          // Only re-queue the target when it is not already on this branch.
          if (kind == 'dir') {
            if (ignoreDirs.contains(name)) continue;
            final relative = _relativeTo(rootPath, entity.path);
            entries.add(FileEntry(relative: relative, kind: 'dir'));
            queue.add((entity.path, target, childAncestors));
            continue;
          }
          if (ignoreFiles.contains(name)) continue;
          entries.add(FileEntry(
            relative: _relativeTo(rootPath, entity.path),
            kind: 'file',
          ));
          continue;
        } on FileSystemException {
          continue;
        }
      }

      if (entity is Directory) {
        if (ignoreDirs.contains(name)) continue;
        // Directories are indexed entries too, so the picker can reference
        // one path without inspecting its descendants at send time.
        entries.add(FileEntry(
          relative: _relativeTo(rootPath, entity.path),
          kind: 'dir',
        ));
        queue.add((
          entity.path,
          entity.path,
          childAncestors,
        ));
        continue;
      }
      if (entity is File) {
        if (ignoreFiles.contains(name)) continue;
        entries.add(FileEntry(
          relative: _relativeTo(rootPath, entity.path),
          kind: 'file',
        ));
      }
    }
    if (truncated) break;
  }

  entries.sort((a, b) => a.relative.compareTo(b.relative));
  return WorkspaceIndex(entries: entries, truncated: truncated);
}

/// Forward-slash display path of [child] relative to [root].
String _relativeTo(String root, String child) =>
    p.relative(child, from: root).replaceAll(p.separator, '/');
