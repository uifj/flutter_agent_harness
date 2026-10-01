// The source-control tab.
//
// A port of `DSH-better-sidebar/src/client/GitView.tsx` over the in-process
// `lib/host/git.dart` instead of the source's HTTP api. Status, branch
// switch, commit box and a paged history, rows opening diff tabs and
// right-click menus, destructive actions behind a confirm dialog — all as in
// the source. What the source does that this does not:
//
//   * Worktree and multi-repository selectors. The source's session can
//     address several linked checkouts at once, and its whole refresh
//     discipline exists to keep rows from two checkouts from mixing; this app
//     has exactly one workspace root, so there is nothing to choose and the
//     generation counter the choice needed collapses to "is this still the
//     repo I started the call with".
//   * The 2s poll runs only while this tab is the *active* tab of its pane —
//     the port's `visible` — since a body kept alive in an [IndexedStack]
//     (see pane.dart) is off-stage, not gone.
//
// The XY-letter helpers (`badgeOf` and friends) used to live here because this
// was the only reader and the source keeps them in GitView.tsx. The file tree
// became the second reader, so they moved to `host/git.dart` next to the type
// they read (ADR-0043) — still pure, still testable without a repository.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput, ShadOption;
import 'package:path/path.dart' as p;

import '../../../host/git.dart';
import '../../../l10n/locales.dart';
import '../../../theme/dsw_shape.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../model/sidebar_tab.dart';
import '../../../state/git_status_store.dart';
import '../../../state/workbench_controller.dart';
import '../../primitives/menu.dart';
import '../../primitives/reveal.dart';
import '../../primitives/tappable.dart';
import '../../primitives/confirm_dialog.dart';
import '../../primitives/icon_button.dart';

// ---- The view vocabulary, ported from GitView.tsx --------------------------

/// The ref names of one log row's decorations (`HEAD -> main` → `main`), deduped.
List<String> refNames(String refs) {
  return [
    ...{
      for (final raw in refs.split(','))
        if (raw.trim().isNotEmpty) _plainRef(raw.trim()),
    },
  ];
}

/// `HEAD -> main` keeps the side after the arrow; `tag: v1.0` loses its
/// prefix — the two shapes `%D` decorates a row with.
String _plainRef(String ref) {
  var name = ref;
  final arrow = name.indexOf(' -> ');
  if (arrow >= 0) name = name.substring(arrow + 4);
  if (name.startsWith('tag: ')) name = name.substring(5);
  return name;
}

/// `2024-01-01 10:00:00 +0800` — git's `%ai` — as a DateTime, or null.
///
/// [DateTime.parse] cannot read the space-separated offset, so the two shapes
/// git emits are rewritten into ISO 8601 first.
DateTime? parseGitDate(String raw) {
  final match = RegExp(
    r'^(\d{4}-\d{2}-\d{2}) (\d{2}:\d{2}:\d{2})(?: ([+-])(\d{2})(\d{2}))?$',
  ).firstMatch(raw.trim());
  if (match == null) return DateTime.tryParse(raw);
  var iso = '${match.group(1)}T${match.group(2)}';
  if (match.group(3) != null) {
    iso += '${match.group(3)}${match.group(4)}:${match.group(5)}';
  }
  return DateTime.tryParse(iso);
}

/// The relative age the history rows show — the source's `relativeTime`.
///
/// `now` is injectable so the thresholds are testable against fixed times.
String relativeTime(String iso, {DateTime Function()? now}) {
  final then = parseGitDate(iso);
  if (then == null) return iso;
  final seconds = (now ?? DateTime.now)().difference(then).inSeconds;
  if (seconds < 60) return 'just now';
  if (seconds < 3600) return '${seconds ~/ 60} min ago';
  if (seconds < 86400) return '${seconds ~/ 3600} h ago';
  if (seconds < 172800) return 'yesterday';
  final month = then.month.toString().padLeft(2, '0');
  final day = then.day.toString().padLeft(2, '0');
  return '${then.year}-$month-$day';
}

// ---- The host --------------------------------------------------------------

/// The git seam, in reach of tab bodies.
///
/// Same reason as [TerminalHost] in terminal_tab.dart: bodies are built by the
/// global registry, whose builders cannot capture an app-scoped object without
/// pinning whichever instance registered first. The runner — not a repo — is
/// what rides on the scope, because a repo is a function of the workspace root,
/// which the tab re-resolves when it changes.
class GitHost extends InheritedWidget {
  const GitHost({
    super.key,
    required this.runner,
    required this.status,
    required super.child,
  });

  final GitRunner runner;

  /// The one cache behind every "what is dirty" in the workbench: the panel and
  /// the file tree read the same reading, and one of them pays for it
  /// (ADR-0043).
  final GitStatusStore status;

  /// The runner below [context]. Throws rather than defaulting: a git tab
  /// outside a GitHost is a wiring bug, and a silent fallback would spawn real
  /// git where a test meant to fake it.
  static GitRunner of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<GitHost>();
    if (host == null) {
      throw StateError('GitTab needs a GitHost ancestor');
    }
    return host.runner;
  }

  /// The shared status cache. Same rule as [of]: no silent fallback to the real
  /// binary, because the fake runner is what keeps these tabs testable.
  static GitStatusStore statusOf(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<GitHost>();
    if (host == null) {
      throw StateError('git readers need a GitHost ancestor');
    }
    return host.status;
  }

  @override
  bool updateShouldNotify(GitHost oldWidget) =>
      runner != oldWidget.runner || status != oldWidget.status;
}

// ---- The tab ----------------------------------------------------------------

/// How much history loads at once — the source's LOG_BATCH.
const _logBatch = 20;

class GitTab extends StatefulWidget {
  const GitTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<GitTab> createState() => _GitTabState();
}

class _GitTabState extends State<GitTab> {
  GitRunner? _runner;

  /// The repository, or null when the workspace is not a work tree.
  GitRepo? _repo;

  /// The workspace root that was probed for [_repo] — successful or not, so a
  /// non-repo is not re-probed on every workbench notification.
  String? _probedRoot;

  bool _opening = false;
  bool _refreshing = false;
  bool _loading = true;
  String? _error;

  GitStatusResult? _status;
  List<String> _branches = const [];
  List<GitLogEntry> _log = const [];
  bool _logEnded = false;
  bool _logLoadingMore = false;

  bool _busy = false;
  String? _actionError;
  final _commitMsg = TextEditingController();

  Timer? _poll;

  /// The shared status cache, taken from [GitHost] on the first dependency pass.
  GitStatusStore? _store;

  @override
  void initState() {
    super.initState();
    widget.workbench.addListener(_onWorkbench);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runner ??= GitHost.of(context);
    if (_store == null) {
      _store = GitHost.statusOf(context)
        // The tree can be the one that asks git; when it does, this panel is a
        // reader of the same answer rather than a viewer of its own last one.
        ..addListener(_onStoreChange);
      // The interval is the store's number, not a literal in this view: one
      // freshness for both readers (ADR-0043 D2).
      _poll = Timer.periodic(GitStatusStore.freshness, _tick);
    }
    _openRepo();
  }

  void _onStoreChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _poll?.cancel();
    _store?.removeListener(_onStoreChange);
    widget.workbench.removeListener(_onWorkbench);
    _commitMsg.dispose();
    super.dispose();
  }

  /// The workspace root moving means the repository has to be found again —
  /// and everything derived from the old one retired before the new one
  /// resolves, exactly as the source does for a worktree switch.
  void _onWorkbench() {
    if (widget.workbench.workspaceRoot != _probedRoot) _openRepo();
  }

  void _tick(_) {
    // Only while this tab is the one its pane is showing. A body kept alive in
    // a pane's IndexedStack is off-stage, not visible, and polling it is git
    // churn for pixels nobody sees.
    if (!_visible || _busy) return;
    _refresh(silent: true);
  }

  bool get _visible {
    final pane = widget.workbench.state.paneOf(widget.tab.id);
    return pane != null && pane.active == widget.tab.id;
  }

  Future<void> _openRepo() async {
    final runner = _runner;
    final root = widget.workbench.workspaceRoot;
    if (runner == null || _opening) return;
    if (root == null) {
      if (_probedRoot != null) {
        setState(() {
          _repo = null;
          _probedRoot = null;
          _status = null;
          _branches = const [];
          _log = const [];
          _loading = false;
          _error = null;
        });
      }
      return;
    }
    if (root == _probedRoot) return;
    _opening = true;
    setState(() => _loading = true);
    try {
      final repo = await openRepo(root, runner: runner);
      if (!mounted || widget.workbench.workspaceRoot != root) return;
      setState(() {
        _repo = repo;
        _probedRoot = root;
        _status = null;
        _branches = const [];
        _log = const [];
        _logEnded = false;
        _actionError = null;
        // A directory that is not a work tree resolves here and now: there is
        // nothing further to load, and leaving the spinner up would hide the
        // not-a-repo notice behind it forever.
        _loading = repo != null;
      });
      if (repo != null) await _refresh();
    } finally {
      _opening = false;
    }
  }

  /// Publishes a complete checkout-derived view. Status, branch choices and
  /// history are one consistency unit, never mixed across roots — hence the
  /// repo identity check after every await.
  Future<void> _refresh({bool silent = false}) async {
    final repo = _repo;
    final store = _store;
    if (repo == null || store == null || _refreshing) return;
    _refreshing = true;
    if (!silent) setState(() => _loading = true);
    try {
      // The cache decides what "fresh" means; a manual press or an action
      // forces, a poll does not, and a tree that asked first is not re-asked.
      final status = await store.read(repo.root, force: !silent);
      if (!mounted || _repo != repo) return;
      final failure = store.errorFor(repo.root);
      if (failure != null) {
        // This panel asked on purpose, so it is the reader that says why. The
        // tree stays silent about the same failure.
        setState(() {
          _error = failure;
          _loading = false;
        });
        return;
      }
      if (silent) {
        // A poll may update status alone; everything else waits for a manual
        // or action-driven refresh, as in the source.
        setState(() => _status = status);
        return;
      }
      var branches = const <String>[];
      var log = const <GitLogEntry>[];
      try {
        branches = await repo.branches();
      } on GitCommandError {
        // A repository with no branches yet (unborn HEAD) has an empty list to
        // show, not an error — the source's `.catch(() => ({names: []}))`.
      }
      try {
        log = await repo.log(count: _logBatch);
      } on GitCommandError {
        // Ditto: an unborn repository has no history, not a broken panel.
      }
      if (!mounted || _repo != repo) return;
      setState(() {
        _status = status;
        _branches = branches;
        _log = log;
        _logEnded = log.length < _logBatch;
        _error = null;
        _loading = false;
      });
    } on GitCommandError catch (error) {
      if (mounted && _repo == repo) {
        setState(() {
          _error = error.message;
          _loading = false;
        });
      }
    } finally {
      _refreshing = false;
    }
  }

  /// One git-writing gesture: busy around it, refreshed after it, the failure
  /// as text where the commit box is. [prefix] is the label the source gives
  /// the error ('Branch switch failed', 'Failed to load more history') or null
  /// for the bare message.
  Future<void> _run(String? prefix, Future<void> Function() action) async {
    final repo = _repo;
    if (repo == null || _busy) return;
    setState(() {
      _busy = true;
      _actionError = null;
    });
    try {
      await action();
      // The command just changed the working tree's answer, so the next reader
      // — this panel or the file tree — must not be served the pre-action cache.
      _store?.invalidate(repo.root);
      await _refresh();
    } on GitCommandError catch (error) {
      if (mounted) {
        setState(
          () => _actionError = prefix == null
              ? error.message
              : '$prefix: ${error.message}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _commit() async {
    final message = _commitMsg.text.trim();
    final repo = _repo;
    if (message.isEmpty || repo == null || _busy) return;
    await _run(null, () async {
      await repo.commit(message);
      _commitMsg.clear();
    });
  }

  Future<void> _loadMoreLog() async {
    final repo = _repo;
    if (repo == null || _logLoadingMore || _logEnded) return;
    setState(() => _logLoadingMore = true);
    try {
      final next = await repo.log(count: _logBatch, skip: _log.length);
      if (!mounted || _repo != repo) return;
      setState(() {
        _log = [..._log, ...next];
        _logEnded = next.length < _logBatch;
      });
    } on GitCommandError catch (error) {
      if (mounted) {
        setState(
          () => _actionError = context.tr('historyLoadError', {
            'message': error.message,
          }),
        );
      }
    } finally {
      if (mounted) setState(() => _logLoadingMore = false);
    }
  }

  Future<void> _stageEntry(GitStatusEntry entry, bool staged) => _run(
    null,
    () => staged ? _repo!.unstage(entry.path) : _repo!.stage(entry.path),
  );

  Future<void> _stageAll(bool staged) =>
      _run(null, () => staged ? _repo!.unstage(null) : _repo!.stage(null));

  /// The pending destructive action's Cancel / Confirm, as a dialog.
  Future<bool> _confirm(
    String title,
    String description,
    String confirmLabel,
  ) async {
    return showConfirmDialog(
      context,
      title: title,
      description: description,
      confirmLabel: confirmLabel,
    );
  }

  Future<void> _copy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  /// The diff tab for one changed file. Staged and unstaged are two different
  /// diffs of the same path and get two different tabs.
  void _openWorktreeDiff(GitStatusEntry entry, bool staged) {
    final root = _repo!.root;
    widget.workbench.openDiff(
      WorktreeDiff(
        path: p.join(root, entry.path),
        staged: staged,
        untracked: isUntracked(entry),
      ),
    );
  }

  /// The diff tab for one commit.
  void _openCommitDiff(GitLogEntry entry) {
    widget.workbench.openDiff(
      CommitDiff(hashFull: entry.hashFull, subject: entry.subject),
    );
  }

  /// The changed file's right-click menu, as rows for [DswContextMenu].
  List<DswMenuEntry> _fileMenuItems(
    BuildContext context,
    GitStatusEntry entry,
    bool staged,
  ) {
    final root = _repo!.root;
    final absolute = p.join(root, entry.path);
    // A path outside the workspace fence cannot be opened in the editor: the
    // host guard rejects it. The menu hides the action for that checkout
    // rather than offering a no-op.
    final openable = widget.workbench.workspace?.tryResolve(absolute);
    // Whether this row can point at a tree at all: `openFolder` refuses a
    // disabled tab type, and a menu entry that does nothing is the defect
    // ADR-0022 names — so it is not offered rather than being half-offered.
    final treeRoot = widget.workbench.workspaceRoot;
    final hasTree =
        openable != null &&
        treeRoot != null &&
        !widget.workbench.disabledTabs.contains(BuiltinTabType.explorer);
    // Read while this context is certainly good: the strings are used after an
    // await inside the action below.
    final discardTitle = context.tr('discardChanges');
    final discardDesc = context.tr('discardDesc', {'path': entry.path});
    return [
      if (openable != null)
        DswMenuEntry(
          icon: LucideIcons.code,
          label: context.tr('openEditor'),
          onTap: () => widget.workbench.openFile(openable),
        ),
      DswMenuEntry(
        icon: staged ? LucideIcons.trash : LucideIcons.git_branch,
        label: staged ? context.tr('unstage') : context.tr('stage'),
        onTap: () => _stageEntry(entry, staged),
      ),
      if (!isUntracked(entry))
        DswMenuEntry(
          icon: LucideIcons.trash,
          label: discardTitle,
          destructive: true,
          onTap: () async {
            if (await _confirm(discardTitle, discardDesc, discardTitle)) {
              await _run(null, () => _repo!.discard(entry.path));
            }
          },
        ),
      const DswMenuEntry.divider(),
      DswMenuEntry(
        icon: LucideIcons.copy,
        label: context.tr('copyRelative'),
        onTap: () => _copy(entry.path),
      ),
      DswMenuEntry(
        icon: LucideIcons.copy,
        label: context.tr('copyAbsolute'),
        onTap: () => _copy(absolute),
      ),
      DswMenuEntry(
        icon: LucideIcons.external_link,
        label: context.tr('revealInFiles'),
        onTap: () => revealInFilesOrReport(context, absolute),
      ),
      // Two existing verbs in this order: without the first, the second expands
      // ancestors in a tree that is not on screen (ADR-0041).
      if (hasTree)
        DswMenuEntry(
          icon: LucideIcons.folder_tree,
          label: context.tr('revealInTree'),
          onTap: () {
            widget.workbench.openFolder(treeRoot);
            widget.workbench.reveal([absolute]);
          },
        ),
    ];
  }

  /// The history row's right-click menu, as rows for [DswContextMenu].
  List<DswMenuEntry> _historyMenuItems(
    BuildContext context,
    GitLogEntry entry,
  ) {
    // Read before any await, as in `_fileMenuItems`.
    final revertTitle = context.tr('revertCommit');
    final revertDesc = context.tr('revertDesc', {'subject': entry.subject});
    final cherryPickTitle = context.tr('cherryPickCommit');
    final cherryPickDesc = context.tr('cherryPickDesc', {
      'subject': entry.subject,
    });
    return [
      DswMenuEntry(
        label: context.tr('viewCommitDiff'),
        onTap: () => _openCommitDiff(entry),
      ),
      DswMenuEntry(
        icon: LucideIcons.copy,
        label: context.tr('copyShortHash'),
        onTap: () => _copy(entry.hash),
      ),
      DswMenuEntry(
        icon: LucideIcons.copy,
        label: context.tr('copyFullHash'),
        onTap: () => _copy(entry.hashFull),
      ),
      DswMenuEntry(
        icon: LucideIcons.copy,
        label: context.tr('copySubject'),
        onTap: () => _copy(entry.subject),
      ),
      const DswMenuEntry.divider(),
      DswMenuEntry(
        label: revertTitle,
        destructive: true,
        onTap: () async {
          if (await _confirm(revertTitle, revertDesc, revertTitle)) {
            await _run(null, () => _repo!.revert(entry.hashFull));
          }
        },
      ),
      DswMenuEntry(
        label: cherryPickTitle,
        destructive: true,
        onTap: () async {
          if (await _confirm(
            cherryPickTitle,
            cherryPickDesc,
            cherryPickTitle,
          )) {
            await _run(null, () => _repo!.cherryPick(entry.hashFull));
          }
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workbench.workspaceRoot == null) {
      return _Notice(message: context.tr('noWorkspaceNothingToList'));
    }
    final status = _status;
    return CustomScrollView(
      primary: false,
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        if (_loading)
          SliverToBoxAdapter(
            child: _Notice(message: context.tr('loading'), center: true),
          ),
        if (!_loading && _error != null)
          SliverToBoxAdapter(child: _ErrorBox(message: _error!)),
        if (!_loading && _error == null && _repo == null)
          SliverToBoxAdapter(
            child: _Notice(message: context.tr('gitNotARepo'), center: true),
          ),
        if (!_loading && _error == null && status != null && status.isRepo) ...[
          if (status.truncated)
            SliverToBoxAdapter(
              child: _Notice(message: context.tr('gitTooManyChanges')),
            ),
          ..._section(
            title: context.tr('stagedCount', {
              'n': status.entries.where(isStagedEntry).length,
            }),
            link: status.entries.any(isStagedEntry)
                ? (context.tr('unstageAll'), () => _stageAll(true))
                : null,
            entries: status.entries.where(isStagedEntry).toList(),
            staged: true,
          ),
          ..._section(
            title: context.tr('unstagedCount', {
              'n': status.entries.where(isUnstagedEntry).length,
            }),
            link: status.entries.any(isUnstagedEntry)
                ? (context.tr('stageAll'), () => _stageAll(false))
                : null,
            entries: status.entries.where(isUnstagedEntry).toList(),
            staged: false,
          ),
          SliverToBoxAdapter(child: _commitBox(context)),
          if (_actionError != null)
            SliverToBoxAdapter(child: _ErrorBox(message: _actionError!)),
          SliverToBoxAdapter(
            child: _SectionHeader(title: context.tr('history')),
          ),
          SliverList.builder(
            itemCount: _log.length,
            itemBuilder: (context, index) => DswContextMenu(
              items: (context) => _historyMenuItems(context, _log[index]),
              minWidth: 220,
              child: _LogRow(
                entry: _log[index],
                onTap: () => _openCommitDiff(_log[index]),
              ),
            ),
          ),
          if (!_logEnded)
            SliverToBoxAdapter(
              child: _LoadMore(loading: _logLoadingMore, onTap: _loadMoreLog),
            ),
        ],
      ],
    );
  }

  /// The branch selector and the refresh control — `.gitHeader`. Inside the
  /// scroll view, as in the source: the header scrolls with the panel.
  Widget _header(BuildContext context) {
    final current = _status?.branch;
    return Container(
      // One row of chrome holding the branch chip, so the row can't stay
      // shorter than the chip inside it (pinned at 36 it squeezed the scaled
      // chip's name down to 34 of the 40 it wanted at 2.2x).
      height: 36 * MediaQuery.textScalerOf(context).scale(1),
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(
        children: [
          Expanded(
            child: _BranchSelect(
              value: current,
              branches: _branches,
              enabled: !_busy && _status?.isRepo == true,
              onSelected: (branch) {
                if (branch == current) return;
                _run(
                  context.tr('branchSwitchFailed'),
                  () => _repo!.checkout(branch),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          DswIconButton(
            icon: LucideIcons.refresh_cw,
            tooltip: context.tr('refresh'),
            onTap: _busy ? null : _refresh,
          ),
        ],
      ),
    );
  }

  List<Widget> _section({
    required String title,
    required List<GitStatusEntry> entries,
    required bool staged,
    (String, VoidCallback)? link,
  }) {
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(title: title, link: link),
      ),
      if (entries.isEmpty)
        SliverToBoxAdapter(child: _Notice(message: context.tr('noChanges')))
      else
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) => DswContextMenu(
            items: (context) => _fileMenuItems(context, entries[index], staged),
            minWidth: 220,
            child: _FileRow(
              entry: entries[index],
              staged: staged,
              busy: _busy,
              onTap: () => _openWorktreeDiff(entries[index], staged),
              onStage: () => _stageEntry(entries[index], staged),
            ),
          ),
        ),
    ];
  }

  Widget _commitBox(BuildContext context) {
    final color = context.dsw;
    final canCommit =
        !_busy &&
        _commitMsg.text.trim().isNotEmpty &&
        (_status?.entries.where(isStagedEntry).isNotEmpty ?? false);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: CallbackShortcuts(
              bindings: {
                const SingleActivator(LogicalKeyboardKey.enter, control: true):
                    _commit,
                const SingleActivator(LogicalKeyboardKey.enter, meta: true):
                    _commit,
              },
              child: ShadInput(
                controller: _commitMsg,
                enabled: !_busy,
                style: DswType.xs13.copyWith(color: color.labelPrimary),
                placeholder: Text(
                  context.tr('commitPlaceholder'),
                  // The hint is the one thing in this box that may be cut: the
                  // message the user types is what has to fit. Left to itself
                  // at 1.8x it wrapped to a second line this field then
                  // clipped (measured: 72.0 wanted, 36.0 given).
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.xs13.copyWith(color: color.labelCaption),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _CommitButton(
            label: context.tr('commit'),
            enabled: canCommit,
            onTap: _commit,
          ),
        ],
      ),
    );
  }
}

// ---- The pieces --------------------------------------------------------------

/// `.gitSectionHeader`: uppercase caption with the optional action link.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.link});

  final String title;

  /// The ('Unstage all', handler) pair, shown only when the section has rows.
  final (String, VoidCallback)? link;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: DswType.xxxsStrong11.copyWith(color: color.labelTertiary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (link != null) _LinkButton(label: link!.$1, onTap: link!.$2),
        ],
      ),
    );
  }
}

/// `.gitLink` — the brand-coloured text action in a section header.
class _LinkButton extends StatefulWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // The visible label is the accessible name.
    return DswHoverTap(
      onTap: widget.onTap,
      builder: (context, hovered, _) => Text(
        widget.label,
        style: DswType.xxxs11.copyWith(
          color: color.brandPrimary,
          decoration: hovered ? TextDecoration.underline : null,
        ),
      ),
    );
  }
}

/// One changed file — `.gitRow`: badge + path, the stage/unstage affordance,
/// a click opening the diff tab, a right-click opening the menu. The row is a
/// DswHoverTap (keyboard-focusable, announced as a button whose name is the
/// path); the nested stage button is its own focusable control.
class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.entry,
    required this.staged,
    required this.busy,
    required this.onTap,
    required this.onStage,
  });

  final GitStatusEntry entry;
  final bool staged;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onStage;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // No secondary tap here on purpose: the `DswContextMenu` the host wraps
    // this row in claims the right button, and the deeper recognizer would win
    // the arena instead.
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: entry.path,
      excludeSemantics: true,
      builder: (context, hovered, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(minHeight: 34),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : Colors.transparent,
          borderRadius: BorderRadius.circular(DswShape.control),
        ),
        child: Row(
          children: [
            Expanded(
              child: Tooltip(
                message: entry.path,
                child: Row(
                  children: [
                    Container(
                      // A one-glyph square, so both sides ride the text step:
                      // pinned at 16 it cut its own letter (25.0 wanted at 1.8,
                      // 31.0 at 2.2) while the row it sits in grew around it.
                      width: 20 * MediaQuery.textScalerOf(context).scale(1),
                      height: 16 * MediaQuery.textScalerOf(context).scale(1),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: color.interactiveBgHover,
                        borderRadius: BorderRadius.circular(DswShape.inset),
                      ),
                      child: Text(
                        badgeOf(entry),
                        style: DswType.xxxsStrong11.copyWith(
                          color: color.labelSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.path,
                        style: DswType.s14.copyWith(color: color.labelPrimary),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            DswIconButton(
              icon: staged ? LucideIcons.trash : LucideIcons.git_branch,
              tooltip: staged ? context.tr('unstage') : context.tr('stage'),
              onTap: busy ? null : onStage,
            ),
          ],
        ),
      ),
    );
  }
}

/// One history row — `.gitLogRow`: hash + subject, then ref pills and meta.
/// A keyboard-focusable row (opened diff on Enter); its accessible name is the
/// commit subject, not the hash/pills/meta chatter.
class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry, required this.onTap});

  final GitLogEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // No secondary tap here either — the host's `DswContextMenu` owns it.
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: entry.subject,
      excludeSemantics: true,
      builder: (context, hovered, _) => Tooltip(
        message: '${entry.author} · ${entry.date}\n${entry.hashFull}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(DswShape.control),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    entry.hash,
                    style: DswType.markdownCodeBlockSmall.copyWith(
                      color: color.labelTertiary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.subject,
                      style: DswType.s14.copyWith(color: color.labelPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Wrap(
                spacing: 6,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final ref in refNames(entry.refs))
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        border: Border.all(color: color.borderL2),
                        borderRadius: BorderRadius.circular(DswShape.pill),
                      ),
                      child: Text(
                        ref,
                        style: DswType.xxxsStrong11.copyWith(
                          color: color.brandPrimary,
                        ),
                      ),
                    ),
                  Text(
                    '${entry.author} · ${relativeTime(entry.date)}',
                    style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.gitBranchSelect` as a menu: the current branch, and the others below it.
class _BranchSelect extends StatelessWidget {
  const _BranchSelect({
    required this.value,
    required this.branches,
    required this.enabled,
    required this.onSelected,
  });

  final String? value;
  final List<String> branches;
  final bool enabled;
  final void Function(String) onSelected;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswSelect<String>(
      value: value,
      onChanged: (picked) {
        if (picked != null) onSelected(picked);
      },
      enabled: enabled && branches.isNotEmpty,
      popupMinWidth: 120,
      options: (context, close) => [
        for (final name in branches)
          ShadOption<String>(
            value: name,
            child: Text(
              name,
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      trigger: (context, selected, hovered) => Container(
        // The chip and its menu are the same seat at the same step: 26 pinned
        // this 12px name down to one clipped line (32.0 wanted at 1.8).
        height: 26 * MediaQuery.textScalerOf(context).scale(1),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgHover : color.bgBase,
          border: Border.all(color: color.borderL2),
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? '',
                style: DswType.xxs12.copyWith(color: color.labelPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            Icon(
              LucideIcons.chevron_down,
              size: DswShape.iconSm,
              color: enabled ? color.labelTertiary : color.labelCaption,
            ),
          ],
        ),
      ),
    );
  }
}

/// `.gitCommitButton` — the primary commit affordance.
class _CommitButton extends StatefulWidget {
  const _CommitButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_CommitButton> createState() => _CommitButtonState();
}

class _CommitButtonState extends State<_CommitButton> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: widget.enabled ? widget.onTap : null,
      enabled: widget.enabled,
      builder: (context, hovered, _) => Opacity(
        opacity: widget.enabled ? 1 : 0.45,
        child: Container(
          // Grows with the input it stands beside: the label is one line of
          // 12px, and 26 pinned cut it (32.0 wanted at 1.8).
          height: 26 * MediaQuery.textScalerOf(context).scale(1),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: hovered && widget.enabled
                ? color.buttonPrimaryHover
                : color.buttonPrimaryFill,
            borderRadius: BorderRadius.circular(DswShape.inner),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: DswType.xxsStrong12.copyWith(
                color: color.labelPrimaryInverted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.gitLogMore` — the full-width pager at the end of the history.
class _LoadMore extends StatefulWidget {
  const _LoadMore({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  State<_LoadMore> createState() => _LoadMoreState();
}

class _LoadMoreState extends State<_LoadMore> {
  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = !widget.loading;
    return DswHoverTap(
      onTap: enabled ? widget.onTap : null,
      enabled: enabled,
      builder: (context, hovered, _) => Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: hovered && enabled
              ? color.interactiveBgHover
              : Colors.transparent,
          border: Border.all(color: color.borderL2),
          borderRadius: BorderRadius.circular(DswShape.inner),
        ),
        child: Center(
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Text(
              widget.loading ? context.tr('loading') : context.tr('loadMore'),
              style: DswType.xxs12.copyWith(
                color: hovered && enabled
                    ? color.labelPrimary
                    : color.labelSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.gitEmpty` / `.gitPlaceholder` — quiet filler text.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.center = false});

  final String message;

  /// True for the full-panel placeholders (loading, not-a-repo), false for the
  /// in-section ones, whose padding differs.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: center
          ? const EdgeInsets.all(16)
          : const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Text(
        message,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: DswType.xxs12.copyWith(color: color.labelTertiary),
      ),
    );
  }
}

/// `.gitError` — command failures, kept visible with pre-wrap for multi-line
/// git stderr.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        message,
        softWrap: true,
        style: DswType.xxs12.copyWith(color: color.stateErrorPrimary),
      ),
    );
  }
}
