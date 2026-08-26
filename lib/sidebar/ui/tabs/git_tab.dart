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
// The XY-letter helpers (`badgeOf` and friends) live here rather than in
// `git.dart` because they are this view's vocabulary, exactly as they live in
// GitView.tsx in the source — and being pure, they are testable without a
// repository or a widget binding.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../../host/git.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../model/sidebar_tab.dart';
import '../../state/workbench_controller.dart';

// ---- The view vocabulary, ported from GitView.tsx --------------------------

/// The XY status letters a row badge shows (X = index, Y = worktree).
String badgeOf(GitStatusEntry entry) {
  final index = entry.xy[0];
  final worktree = entry.xy[1];
  if (index != ' ' && index != '?') return index;
  if (worktree != ' ' && worktree != '?') return worktree;
  return '?';
}

/// Whether the entry carries STAGED (index) changes — the X letter is set.
bool isStagedEntry(GitStatusEntry entry) {
  final index = entry.xy[0];
  return index != ' ' && index != '?';
}

/// Whether the entry carries UNSTAGED (worktree) changes — the Y letter is set
/// (untracked `??` counts as unstaged: it is a worktree-only change). A file
/// with both letters set ('MM') lands in BOTH sections.
bool isUnstagedEntry(GitStatusEntry entry) {
  if (entry.xy == '??') return true;
  final worktree = entry.xy[1];
  return worktree != ' ' && worktree != '?';
}

/// Whether the entry is untracked (`??`): git diff never includes it.
bool isUntracked(GitStatusEntry entry) => badgeOf(entry) == '?';

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
    required super.child,
  });

  final GitRunner runner;

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

  @override
  bool updateShouldNotify(GitHost oldWidget) => runner != oldWidget.runner;
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

  @override
  void initState() {
    super.initState();
    widget.workbench.addListener(_onWorkbench);
    _poll = Timer.periodic(const Duration(seconds: 2), _tick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runner ??= GitHost.of(context);
    _openRepo();
  }

  @override
  void dispose() {
    _poll?.cancel();
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
    if (repo == null || _refreshing) return;
    _refreshing = true;
    if (!silent) setState(() => _loading = true);
    try {
      final status = await repo.status();
      if (!mounted || _repo != repo) return;
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
      await _refresh();
    } on GitCommandError catch (error) {
      if (mounted) {
        setState(() => _actionError = prefix == null ? error.message : '$prefix: ${error.message}');
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
        setState(() => _actionError = 'Failed to load more history: ${error.message}');
      }
    } finally {
      if (mounted) setState(() => _logLoadingMore = false);
    }
  }

  Future<void> _stageEntry(GitStatusEntry entry, bool staged) => _run(
    null,
    () => staged
        ? _repo!.unstage(entry.path)
        : _repo!.stage(entry.path),
  );

  Future<void> _stageAll(bool staged) => _run(
    null,
    () => staged ? _repo!.unstage(null) : _repo!.stage(null),
  );

  /// The pending destructive action's Cancel / Confirm, as a dialog.
  Future<bool> _confirm(
    String title,
    String description,
    String confirmLabel,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final color = context.dsw;
        return AlertDialog(
          title: Text(title, style: DswType.sStrong14),
          content: Text(description, style: DswType.xs13),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                confirmLabel,
                style: DswType.xs13.copyWith(color: color.stateErrorPrimary),
              ),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Where a right-click's menu opens, at the cursor.
  RelativeRect _menuAt(Offset global) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(global, global),
      Offset.zero & overlay.size,
    );
  }

  Future<void> _copy(String text) => Clipboard.setData(ClipboardData(text: text));

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
    widget.workbench.openDiff(CommitDiff(hashFull: entry.hashFull, subject: entry.subject));
  }

  Future<void> _fileMenu(TapDownDetails details, GitStatusEntry entry, bool staged) async {
    final root = _repo!.root;
    final absolute = p.join(root, entry.path);
    // A path outside the workspace fence cannot be opened in the editor: the
    // host guard rejects it. The menu hides the action for that checkout
    // rather than offering a no-op.
    final openable = widget.workbench.workspace?.tryResolve(absolute);
    final result = await showMenu<String>(
      context: context,
      position: _menuAt(details.globalPosition),
      // The default menu width is narrower than icon + label rows like
      // "Copy relative path", which would overflow by a pixel or two.
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        if (openable != null)
          PopupMenuItem(
            value: 'open',
            child: _menuRow(LucideIcons.code, 'Open editor'),
          ),
        PopupMenuItem(
          value: 'stage',
          child: _menuRow(
            staged ? LucideIcons.trash_2 : LucideIcons.git_branch,
            staged ? 'Unstage' : 'Stage',
          ),
        ),
        if (!isUntracked(entry))
          PopupMenuItem(
            value: 'discard',
            child: _menuRow(LucideIcons.trash_2, 'Discard changes', danger: true),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'relative',
          child: _menuRow(LucideIcons.copy, 'Copy relative path'),
        ),
        PopupMenuItem(
          value: 'absolute',
          child: _menuRow(LucideIcons.copy, 'Copy absolute path'),
        ),
      ],
    );
    if (result == null) return;
    if (result == 'open' && openable != null) {
      widget.workbench.openFile(openable);
    } else if (result == 'stage') {
      await _stageEntry(entry, staged);
    } else if (result == 'discard') {
      if (await _confirm(
        'Discard changes',
        'This discards the worktree changes of "${entry.path}" (not recoverable).',
        'Discard changes',
      )) {
        await _run(null, () => _repo!.discard(entry.path));
      }
    } else if (result == 'relative') {
      await _copy(entry.path);
    } else if (result == 'absolute') {
      await _copy(absolute);
    }
  }

  Future<void> _historyMenu(TapDownDetails details, GitLogEntry entry) async {
    final result = await showMenu<String>(
      context: context,
      position: _menuAt(details.globalPosition),
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        PopupMenuItem(value: 'view', child: _menuRow(null, 'View commit diff')),
        PopupMenuItem(
          value: 'copyShort',
          child: _menuRow(LucideIcons.copy, 'Copy short hash'),
        ),
        PopupMenuItem(
          value: 'copyFull',
          child: _menuRow(LucideIcons.copy, 'Copy full hash'),
        ),
        PopupMenuItem(
          value: 'copySubject',
          child: _menuRow(LucideIcons.copy, 'Copy subject'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'revert',
          child: _menuRow(null, 'Revert commit', danger: true),
        ),
        PopupMenuItem(
          value: 'cherryPick',
          child: _menuRow(null, 'Cherry-pick commit', danger: true),
        ),
      ],
    );
    if (result == null) return;
    if (result == 'view') {
      _openCommitDiff(entry);
    } else if (result == 'copyShort') {
      await _copy(entry.hash);
    } else if (result == 'copyFull') {
      await _copy(entry.hashFull);
    } else if (result == 'copySubject') {
      await _copy(entry.subject);
    } else if (result == 'revert') {
      if (await _confirm(
        'Revert commit',
        'Create a new commit on the current branch that reverts "${entry.subject}".',
        'Revert commit',
      )) {
        await _run(null, () => _repo!.revert(entry.hashFull));
      }
    } else if (result == 'cherryPick') {
      if (await _confirm(
        'Cherry-pick commit',
        'Apply the changes of "${entry.subject}" to the current branch.',
        'Cherry-pick commit',
      )) {
        await _run(null, () => _repo!.cherryPick(entry.hashFull));
      }
    }
  }

  Widget _menuRow(IconData? icon, String label, {bool danger = false}) {
    final color = context.dsw;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color.labelTertiary),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: DswType.xs13.copyWith(
            color: danger ? color.stateErrorPrimary : color.labelPrimary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.workbench.workspaceRoot == null) {
      return const _Notice(
        message: 'No workspace folder is set, so there is nothing to list.',
      );
    }
    final status = _status;
    return CustomScrollView(
      primary: false,
      slivers: [
        SliverToBoxAdapter(child: _header(context)),
        if (_loading) const SliverToBoxAdapter(child: _Notice(message: 'Loading…', center: true)),
        if (!_loading && _error != null)
          SliverToBoxAdapter(child: _ErrorBox(message: _error!)),
        if (!_loading && _error == null && _repo == null)
          const SliverToBoxAdapter(
            child: _Notice(message: 'This directory is not a git repository', center: true),
          ),
        if (!_loading && _error == null && status != null && status.isRepo) ...[
          if (status.truncated)
            const SliverToBoxAdapter(
              child: _Notice(message: 'Too many changes; showing the first 2,000 entries'),
            ),
          ..._section(
            title: 'Staged (${status.entries.where(isStagedEntry).length})',
            link: status.entries.any(isStagedEntry) ? ('Unstage all', () => _stageAll(true)) : null,
            entries: status.entries.where(isStagedEntry).toList(),
            staged: true,
          ),
          ..._section(
            title: 'Unstaged (${status.entries.where(isUnstagedEntry).length})',
            link: status.entries.any(isUnstagedEntry) ? ('Stage all', () => _stageAll(false)) : null,
            entries: status.entries.where(isUnstagedEntry).toList(),
            staged: false,
          ),
          SliverToBoxAdapter(child: _commitBox(context)),
          if (_actionError != null)
            SliverToBoxAdapter(child: _ErrorBox(message: _actionError!)),
          const SliverToBoxAdapter(child: _SectionHeader(title: 'History')),
          SliverList.builder(
            itemCount: _log.length,
            itemBuilder: (context, index) => _LogRow(
              entry: _log[index],
              onTap: () => _openCommitDiff(_log[index]),
              onMenu: (details) => _historyMenu(details, _log[index]),
            ),
          ),
          if (!_logEnded)
            SliverToBoxAdapter(
              child: _LoadMore(
                loading: _logLoadingMore,
                onTap: _loadMoreLog,
              ),
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
      height: 36,
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
                _run('Branch switch failed', () => _repo!.checkout(branch));
              },
            ),
          ),
          const SizedBox(width: 8),
          _RoundIconButton(
            icon: LucideIcons.refresh_cw,
            tooltip: 'Refresh',
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
      SliverToBoxAdapter(child: _SectionHeader(title: title, link: link)),
      if (entries.isEmpty)
        const SliverToBoxAdapter(child: _Notice(message: 'No changes'))
      else
        SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) => _FileRow(
            entry: entries[index],
            staged: staged,
            busy: _busy,
            onTap: () => _openWorktreeDiff(entries[index], staged),
            onMenu: (details) => _fileMenu(details, entries[index], staged),
            onStage: () => _stageEntry(entries[index], staged),
          ),
        ),
    ];
  }

  Widget _commitBox(BuildContext context) {
    final color = context.dsw;
    final canCommit = !_busy &&
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
                const SingleActivator(LogicalKeyboardKey.enter, control: true): _commit,
                const SingleActivator(LogicalKeyboardKey.enter, meta: true): _commit,
              },
              child: TextField(
                controller: _commitMsg,
                enabled: !_busy,
                style: DswType.xs13.copyWith(color: color.labelPrimary),
                decoration: InputDecoration(
                  hintText: 'Commit message (Ctrl+Enter)',
                  hintStyle: DswType.xs13.copyWith(color: color.labelCaption),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  filled: true,
                  fillColor: color.bgBase,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: color.borderL2),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: color.borderL2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide(color: color.brandPrimary),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _CommitButton(label: 'Commit', enabled: canCommit, onTap: _commit),
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
          if (link != null)
            _LinkButton(label: link!.$1, onTap: link!.$2),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Text(
          widget.label,
          style: DswType.xxxs11.copyWith(
            color: color.brandPrimary,
            decoration: _hovered ? TextDecoration.underline : null,
          ),
        ),
      ),
    );
  }
}

/// One changed file — `.gitRow`: badge + path, the stage/unstage affordance,
/// a click opening the diff tab, a right-click opening the menu.
class _FileRow extends StatefulWidget {
  const _FileRow({
    required this.entry,
    required this.staged,
    required this.busy,
    required this.onTap,
    required this.onMenu,
    required this.onStage,
  });

  final GitStatusEntry entry;
  final bool staged;
  final bool busy;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onMenu;
  final VoidCallback onStage;

  @override
  State<_FileRow> createState() => _FileRowState();
}

class _FileRowState extends State<_FileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onMenu,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          constraints: const BoxConstraints(minHeight: 34),
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: widget.entry.path,
                  waitDuration: const Duration(milliseconds: 600),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 16,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.interactiveBgHover,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeOf(widget.entry),
                          style: DswType.xxxsStrong11.copyWith(
                            color: color.labelSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.entry.path,
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
              _RoundIconButton(
                icon: widget.staged ? LucideIcons.trash_2 : LucideIcons.git_branch,
                tooltip: widget.staged ? 'Unstage' : 'Stage',
                onTap: widget.busy ? null : widget.onStage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One history row — `.gitLogRow`: hash + subject, then ref pills and meta.
class _LogRow extends StatefulWidget {
  const _LogRow({required this.entry, required this.onTap, required this.onMenu});

  final GitLogEntry entry;
  final VoidCallback onTap;
  final void Function(TapDownDetails) onMenu;

  @override
  State<_LogRow> createState() => _LogRowState();
}

class _LogRowState extends State<_LogRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final entry = widget.entry;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapDown: widget.onMenu,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: '${entry.author} · ${entry.date}\n${entry.hashFull}',
          waitDuration: const Duration(milliseconds: 600),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _hovered ? color.interactiveBgHover : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
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
                          borderRadius: BorderRadius.circular(999),
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
    return PopupMenuButton<String>(
      enabled: enabled && branches.isNotEmpty,
      initialValue: value,
      onSelected: onSelected,
      constraints: const BoxConstraints(minWidth: 120),
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        for (final name in branches)
          PopupMenuItem(
            value: name,
            height: 32,
            child: Text(
              name,
              style: DswType.xs13.copyWith(color: color.labelPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: color.bgBase,
          border: Border.all(color: color.borderL2),
          borderRadius: BorderRadius.circular(6),
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
              size: 14,
              color: enabled ? color.labelTertiary : color.labelCaption,
            ),
          ],
        ),
      ),
    );
  }
}

/// `.iconButton` — the 28px round hover-tinted affordance.
class _RoundIconButton extends StatefulWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Null disables — busy, or the action has nothing to act on.
  final VoidCallback? onTap;

  @override
  State<_RoundIconButton> createState() => _RoundIconButtonState();
}

class _RoundIconButtonState extends State<_RoundIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered && enabled ? color.interactiveBgHover : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                widget.icon,
                size: 14,
                color: enabled
                    ? (_hovered ? color.labelPrimary : color.labelSecondary)
                    : color.labelCaption,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.gitCommitButton` — the primary commit affordance.
class _CommitButton extends StatefulWidget {
  const _CommitButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_CommitButton> createState() => _CommitButtonState();
}

class _CommitButtonState extends State<_CommitButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.45,
          child: Container(
            height: 26,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _hovered && widget.enabled
                  ? color.buttonPrimaryHover
                  : color.buttonPrimaryFill,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                widget.label,
                style: DswType.xxsStrong12.copyWith(color: color.labelPrimaryInverted),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = !widget.loading;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: _hovered && enabled ? color.interactiveBgHover : Colors.transparent,
            border: Border.all(color: color.borderL2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Text(
                widget.loading ? 'Loading…' : 'Load more',
                style: DswType.xxs12.copyWith(
                  color: _hovered && enabled ? color.labelPrimary : color.labelSecondary,
                ),
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
      padding: center ? const EdgeInsets.all(16) : const EdgeInsets.fromLTRB(12, 4, 12, 8),
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
