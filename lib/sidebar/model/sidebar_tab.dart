// What one workbench tab is.
//
// A port of the tab half of `DSH-better-sidebar/src/client/state.ts:21-41`. Two
// deliberate narrowings from the source:
//
//   * `meta` is `Map<String, Object?>` rather than the source's `unknown`. The
//     source's own doc comment demands "MUST be JSON-serializable — it is
//     persisted with the layout"; a type that cannot hold anything else turns
//     that comment into a compile error instead of a corrupt session file.
//   * A diff ref carries no `worktree`/`repoRoot`. better-sidebar resolves
//     changes across several repositories at once; this app has exactly one
//     workspace root (see `lib/model/workspace.dart`), so those fields would be
//     two more things to keep in sync with nothing reading them.
//
// [TabType] stays a bare string, as in the source, so the registry in
// `lib/sidebar/ui/tab_registry.dart` remains open to types this file has never
// heard of.

import 'package:path/path.dart' as p;

/// Tab type identifier — the key a [TabDescriptor] registers under.
///
/// A string rather than an enum on purpose: the builtin types are listed in
/// [BuiltinTabType] for the code that mints them, but the registry accepts any
/// key, which is what keeps a new tab type from having to edit this file.
typedef TabType = String;

/// The tab types this app ships. Not a closed set — see [TabType].
abstract final class BuiltinTabType {
  static const explorer = 'explorer';
  static const editor = 'editor';
  static const terminal = 'terminal';
  static const git = 'git';
  static const diff = 'diff';
  static const subagent = 'subagent';
}

/// What a diff tab shows.
sealed class SidebarDiffRef {
  const SidebarDiffRef();

  static SidebarDiffRef? fromJson(Object? raw) {
    if (raw is! Map) return null;
    return switch (raw['kind']) {
      'worktree' when raw['path'] is String => WorktreeDiff(
        path: raw['path'] as String,
        staged: raw['staged'] == true,
        untracked: raw['untracked'] == true,
      ),
      'commit' when raw['hashFull'] is String => CommitDiff(
        hashFull: raw['hashFull'] as String,
        subject: raw['subject'] as String? ?? '',
      ),
      _ => null,
    };
  }

  Map<String, Object?> toJson();

  /// The dedupe identity of the change, used to mint a stable tab id.
  ///
  /// Stability is the whole point: clicking the same file in the git view twice
  /// must focus the open tab rather than stack a second one, and that has to
  /// survive a reload — which rules out a minted counter id.
  String get key;
}

/// An uncommitted change to one path.
class WorktreeDiff extends SidebarDiffRef {
  const WorktreeDiff({
    required this.path,
    required this.staged,
    this.untracked = false,
  });

  /// Absolute path of the changed file.
  final String path;

  /// Staged (index vs HEAD) rather than unstaged (worktree vs index).
  final bool staged;

  /// Not tracked by git at all, so there is no `git diff` to ask for and the
  /// whole file reads as added.
  final bool untracked;

  @override
  Map<String, Object?> toJson() => {
    'kind': 'worktree',
    'path': path,
    'staged': staged,
    if (untracked) 'untracked': true,
  };

  /// Staged and unstaged changes to one path are two different diffs and get
  /// two different tabs — as in `git add -p` land, where they routinely differ.
  @override
  String get key => 'worktree:${staged ? 'index' : 'tree'}:$path';

  @override
  bool operator ==(Object other) =>
      other is WorktreeDiff &&
      other.path == path &&
      other.staged == staged &&
      other.untracked == untracked;

  @override
  int get hashCode => Object.hash('worktree', path, staged, untracked);
}

/// One commit's full patch.
class CommitDiff extends SidebarDiffRef {
  const CommitDiff({required this.hashFull, required this.subject});

  final String hashFull;
  final String subject;

  /// The abbreviation shown in the tab title.
  String get hashShort =>
      hashFull.length <= 7 ? hashFull : hashFull.substring(0, 7);

  @override
  Map<String, Object?> toJson() => {
    'kind': 'commit',
    'hashFull': hashFull,
    'subject': subject,
  };

  @override
  String get key => 'commit:$hashFull';

  @override
  bool operator ==(Object other) =>
      other is CommitDiff &&
      other.hashFull == hashFull &&
      other.subject == subject;

  @override
  int get hashCode => Object.hash('commit', hashFull, subject);
}

/// One open tab.
class SidebarTab {
  const SidebarTab({
    required this.id,
    required this.type,
    required this.title,
    this.path,
    this.diff,
    this.meta,
  });

  /// An editor tab for [absolutePath].
  ///
  /// The id is derived from the path rather than minted, which is what makes
  /// opening the same file twice a focus instead of a second tab — the
  /// `'editor:' + path` convention from `state.ts:143-145`.
  factory SidebarTab.editor(String absolutePath) => SidebarTab(
    id: 'editor:$absolutePath',
    type: BuiltinTabType.editor,
    title: p.basename(absolutePath),
    path: absolutePath,
  );

  /// An explorer tab rooted at [absolutePath].
  factory SidebarTab.explorer(String absolutePath) => SidebarTab(
    id: 'explorer:$absolutePath',
    type: BuiltinTabType.explorer,
    title: p.basename(absolutePath),
    path: absolutePath,
  );

  /// A diff tab for [ref]; the id is the change's identity, so a repeat click
  /// focuses rather than stacks.
  factory SidebarTab.diff(SidebarDiffRef ref) => SidebarTab(
    id: 'diff:${ref.key}',
    type: BuiltinTabType.diff,
    title: switch (ref) {
      WorktreeDiff(:final path, :final staged) =>
        '${p.basename(path)}${staged ? ' (staged)' : ''}',
      CommitDiff(:final hashShort) => hashShort,
    },
    path: switch (ref) {
      WorktreeDiff(:final path) => path,
      CommitDiff() => null,
    },
    diff: ref,
  );

  /// The single-instance git tab.
  static const git = SidebarTab(
    id: 'git',
    type: BuiltinTabType.git,
    title: 'Source Control',
  );

  /// The single-instance sub-agent tab.
  static const subagent = SidebarTab(
    id: 'subagent',
    type: BuiltinTabType.subagent,
    title: 'Sub-agents',
  );

  final String id;
  final TabType type;
  final String title;

  /// The file (editor), the directory (explorer), or absent.
  final String? path;

  /// The change a diff tab shows; null for every other type.
  final SidebarDiffRef? diff;

  /// Tab-owned state, persisted with the layout and restored verbatim.
  final Map<String, Object?>? meta;

  SidebarTab copyWith({
    String? title,
    String? path,
    Map<String, Object?>? meta,
  }) => SidebarTab(
    id: id,
    type: type,
    title: title ?? this.title,
    path: path ?? this.path,
    diff: diff,
    meta: meta ?? this.meta,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    if (path != null) 'path': path,
    if (diff != null) 'diff': diff!.toJson(),
    if (meta != null) 'meta': meta,
  };

  /// Null for anything that does not read back as a tab, so one corrupt entry
  /// costs a tab rather than the whole persisted layout.
  static SidebarTab? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final type = raw['type'];
    if (id is! String || type is! String || id.isEmpty) return null;
    return SidebarTab(
      id: id,
      type: type,
      title: raw['title'] as String? ?? '',
      path: raw['path'] as String?,
      diff: SidebarDiffRef.fromJson(raw['diff']),
      meta: switch (raw['meta']) {
        final Map<String, Object?> meta => meta,
        final Map<Object?, Object?> meta => meta.cast<String, Object?>(),
        _ => null,
      },
    );
  }

  @override
  String toString() => 'SidebarTab($id, $type, "$title")';
}
