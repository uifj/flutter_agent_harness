// The diff tab: one change opened from the source-control tab.
//
// A port of `DSH-better-sidebar/src/client/DiffTab.tsx` (the load discipline —
// which git command answers which ref) and `DiffView.tsx` (the parse and the
// rendering) over the in-process `lib/host/git.dart` instead of the source's
// HTTP api. A worktree ref loads the file's unified diff (`git diff`, staged or
// not); a commit ref loads the commit's full patch. The source's two fallbacks
// are kept: an empty requested side tries the OTHER side once (the change may
// have moved sides since the tab opened), and an untracked file — which
// `git diff` never covers — renders as a full-file addition read from disk.
//
// The parser is a pure function (as `parseUnifiedDiff` is in the source), so
// the framing vocabulary — hunk headers, line kinds, the a//b/ path prefixes,
// the added/deleted/renamed/binary badges, and which files start expanded — is
// testable without a repository. What the source does that this does not:
//
//   * No per-worktree or per-repo resolution — one workspace root (see
//     `lib/model/workspace.dart`), so the ref's path is resolved against the
//     one repository the root probed, exactly as the git tab does.
//   * The untracked fallback reads the file directly rather than through the
//     host's fs.read: the path arrived from git status output joined with the
//     repo root, not from a model tool call, so the workspace fence has nothing
//     to guard against here.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:path/path.dart' as p;

import '../../../host/git.dart';
import '../../../theme/dsw_alias.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../model/sidebar_tab.dart';
import '../../state/workbench_controller.dart';
import '../tab_registry.dart' show readsAsText;
import 'git_tab.dart' show GitHost;

// ---- The parse, ported from DiffView.tsx ------------------------------------

/// One rendered diff line.
enum DiffLineKind { ctx, del, add, meta }

class UnifiedDiffLine {
  const UnifiedDiffLine({
    required this.kind,
    required this.text,
    this.oldNum,
    this.newNum,
  });

  final DiffLineKind kind;

  /// The line content without its diff marker ('' for the no-newline marker).
  final String text;

  /// Old-side line number (null for pure additions / metadata).
  final int? oldNum;

  /// New-side line number (null for pure deletions / metadata).
  final int? newNum;
}

/// One parsed hunk.
class UnifiedDiffHunk {
  const UnifiedDiffHunk({
    required this.oldStart,
    required this.newStart,
    required this.header,
    required this.lines,
  });

  /// The old-side start line (`-a[,b]`).
  final int oldStart;

  /// The new-side start line (`+c[,d]`).
  final int newStart;

  /// The section text after the trailing `@@` (may be empty).
  final String header;

  final List<UnifiedDiffLine> lines;
}

/// One parsed file section of a unified diff.
class UnifiedDiffFile {
  const UnifiedDiffFile({
    required this.oldPath,
    required this.newPath,
    required this.binary,
    required this.hunks,
  });

  /// The `---` path verbatim ('/dev/null' for a new file).
  final String oldPath;

  /// The `+++` path verbatim ('/dev/null' for a deleted file).
  final String newPath;

  /// The file changed with binary content: no hunks to draw.
  final bool binary;

  final List<UnifiedDiffHunk> hunks;
}

/// The hunk header `@@ -a[,b] +c[,d] @@ section` (section may contain '@@').
final _hunkHeaderPattern = RegExp(
  r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@(.*)$',
);

/// The accumulate-then-freeze state the parser reads one section through; the
/// source mutates its plain objects in place, and this is the shape that keeps
/// [UnifiedDiffFile] immutable without changing what the parser accepts.
class _FileBuilder {
  String oldPath = '';
  String newPath = '';
  bool binary = false;
  final hunks = <UnifiedDiffHunk>[];

  UnifiedDiffFile freeze() => UnifiedDiffFile(
    oldPath: oldPath,
    newPath: newPath,
    binary: binary,
    hunks: List.unmodifiable(hunks),
  );
}

/// Parse `git diff --no-color` output into file sections and hunks. Rows
/// outside a file section (leading noise) and metadata rows between the
/// `diff --git`/`---`/`+++` headers and the first hunk (index lines, mode
/// changes, rename/similarity lines) are skipped; a section that never reaches
/// a hunk (a mode/rename-only change) stays hunkless so the caller can still
/// draw its path.
List<UnifiedDiffFile> parseUnifiedDiff(String text) {
  final files = <UnifiedDiffFile>[];
  _FileBuilder? current;
  var inHunk = false;
  final hunkLines = <UnifiedDiffLine>[];
  // The hunk's declared start, read off its header — what the hunk reports as
  // oldStart/newStart when flushed. The running row counters below are
  // separate, as the source's `hunk` object and `oldNum`/`newNum` are: sharing
  // them would stamp the counter's final value onto the hunk's start.
  int? hunkOldStart;
  int? hunkNewStart;
  var hunkHeader = '';
  var oldNum = 0;
  var newNum = 0;

  void flushHunk() {
    // A snapshot, because `current` is assigned in `startFile`'s closure and so
    // never promotes: the snapshot is never reassigned and always does.
    final file = current;
    if (file != null && hunkOldStart != null) {
      file.hunks.add(
        UnifiedDiffHunk(
          oldStart: hunkOldStart!,
          newStart: hunkNewStart!,
          header: hunkHeader,
          lines: List.unmodifiable(hunkLines),
        ),
      );
    }
    hunkLines.clear();
    hunkOldStart = null;
    hunkNewStart = null;
    hunkHeader = '';
    inHunk = false;
  }

  void startFile() {
    flushHunk();
    final file = current;
    if (file != null) files.add(file.freeze());
    current = _FileBuilder();
  }

  for (final raw in text.split('\n')) {
    if (raw.startsWith('diff --git ')) {
      startFile();
      continue;
    }
    final file = current;
    if (file == null) continue;
    if (raw.startsWith('Binary files ') || raw == 'GIT binary patch') {
      flushHunk();
      file.binary = true;
      continue;
    }
    if (raw.startsWith('--- ')) {
      flushHunk();
      file.oldPath = raw.substring(4);
      continue;
    }
    if (raw.startsWith('+++ ')) {
      file.newPath = raw.substring(4);
      continue;
    }
    final match = _hunkHeaderPattern.firstMatch(raw);
    if (match != null) {
      flushHunk();
      hunkOldStart = int.parse(match.group(1)!);
      hunkNewStart = int.parse(match.group(3)!);
      hunkHeader = match.group(5) ?? '';
      oldNum = hunkOldStart!;
      newNum = hunkNewStart!;
      inHunk = true;
      continue;
    }
    if (!inHunk) continue;
    final marker = raw.isEmpty ? '' : raw[0];
    if (marker == r'\') {
      // `\ No newline at end of file`: metadata attached to the previous row.
      hunkLines.add(
        UnifiedDiffLine(kind: DiffLineKind.meta, text: raw.substring(1)),
      );
      continue;
    }
    if (marker == ' ') {
      hunkLines.add(
        UnifiedDiffLine(
          kind: DiffLineKind.ctx,
          text: raw.substring(1),
          oldNum: oldNum,
          newNum: newNum,
        ),
      );
      oldNum += 1;
      newNum += 1;
    } else if (marker == '-') {
      hunkLines.add(
        UnifiedDiffLine(
          kind: DiffLineKind.del,
          text: raw.substring(1),
          oldNum: oldNum,
        ),
      );
      oldNum += 1;
    } else if (marker == '+') {
      hunkLines.add(
        UnifiedDiffLine(
          kind: DiffLineKind.add,
          text: raw.substring(1),
          newNum: newNum,
        ),
      );
      newNum += 1;
    } else {
      // Not a diff line (a hunk can never contain one): stop the hunk.
      flushHunk();
    }
  }
  flushHunk();
  final last = current;
  if (last != null) files.add(last.freeze());
  return files;
}

/// Build the untracked-file shape: one file, one hunk of pure additions.
UnifiedDiffFile untrackedDiffFile(String path, String content) {
  final lines = <UnifiedDiffLine>[];
  final body = content.endsWith('\n')
      ? content.substring(0, content.length - 1)
      : content;
  if (body.isNotEmpty) {
    var num = 1;
    for (final line in body.split('\n')) {
      lines.add(UnifiedDiffLine(kind: DiffLineKind.add, text: line, newNum: num));
      num += 1;
    }
  }
  return UnifiedDiffFile(
    oldPath: '/dev/null',
    newPath: 'b/$path',
    binary: false,
    hunks: [UnifiedDiffHunk(oldStart: 0, newStart: 1, header: '', lines: lines)],
  );
}

/// Strip the `a/` / `b/` prefix git puts on diff paths (not on /dev/null).
String displayDiffPath(String path) {
  if (path == '/dev/null') return path;
  if (path.startsWith('a/') || path.startsWith('b/')) return path.substring(2);
  return path;
}

/// The file header badge: added / deleted / renamed / binary (null for a
/// plain edit), as the source's `fileTag`.
String? diffFileTag(UnifiedDiffFile file) {
  if (file.binary) return 'Binary';
  if (file.oldPath == '/dev/null') return 'Added';
  if (file.newPath == '/dev/null') return 'Deleted';
  final oldPath = displayDiffPath(file.oldPath);
  final newPath = displayDiffPath(file.newPath);
  if (oldPath != newPath) return 'Renamed';
  return null;
}

final _testPath = RegExp(
  r'(^|/)(?:__tests__|tests?|specs?|fixtures?|mocks?|snapshots?)(?:/|$)'
  r'|\.(?:test|spec)\.[^/]+$',
  caseSensitive: false,
);
final _docPath = RegExp(
  r'(^|/)(?:docs?|documentation)(?:/|$)'
  r'|(^|/)(?:readme|changelog|contributing|license|authors|notice)(?:\.[^/]*)?$',
  caseSensitive: false,
);
final _generatedPath = RegExp(
  r'(^|/)(?:dist|build|coverage|generated|vendor|node_modules)(?:/|$)'
  r'|(^|/)(?:package-lock\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?'
  r'|composer\.lock|cargo\.lock|poetry\.lock)$',
  caseSensitive: false,
);
final _sourcePath = RegExp(
  r'\.(?:js|jsx|mjs|cjs|ts|tsx|mts|cts|py|pyw|rb|php|java|kt|kts|scala|go|rs'
  r'|swift|c|h|cc|cpp|cxx|hpp|hh|hxx|cs|fs|fsx|vb|dart|lua|r|ex|exs|erl|hrl'
  r'|clj|cljs|cljc|groovy|sh|bash|zsh|fish|ps1|sql|vue|svelte|astro|html'
  r'|htm|css|scss|sass|less)$',
  caseSensitive: false,
);

/// Source files open by default; tests, docs, generated files and unknown
/// types stay folded — the source's `defaultExpandedFiles`, so a commit
/// touching 40 files opens on the few worth reading.
Set<int> defaultExpandedFiles(List<UnifiedDiffFile> files) {
  final expanded = <int>{};
  for (var index = 0; index < files.length; index++) {
    final file = files[index];
    final path = displayDiffPath(
      file.newPath == '/dev/null' ? file.oldPath : file.newPath,
    );
    if (!file.binary &&
        file.hunks.isNotEmpty &&
        !_testPath.hasMatch(path) &&
        !_docPath.hasMatch(path) &&
        !_generatedPath.hasMatch(path) &&
        _sourcePath.hasMatch(path)) {
      expanded.add(index);
    }
  }
  return expanded;
}

// ---- The tab ----------------------------------------------------------------

/// Flattened display rows so the cap can slice a single list, as in the
/// source's `rows` memo.
sealed class _Row {
  const _Row();
}

class _PathRow extends _Row {
  const _PathRow(this.file, this.index);

  final UnifiedDiffFile file;
  final int index;
}

class _HunkRow extends _Row {
  const _HunkRow(this.hunk);

  final UnifiedDiffHunk hunk;
}

class _LineRow extends _Row {
  const _LineRow(this.line);

  final UnifiedDiffLine line;
}

/// Output rows shown before the cap collapses the middle — the source's
/// MAX_DIFF_ROWS.
const _maxDiffRows = 500;

class DiffTab extends StatefulWidget {
  const DiffTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<DiffTab> createState() => _DiffTabState();
}

class _DiffTabState extends State<DiffTab> {
  GitRunner? _runner;

  /// The repository, or null when the workspace is not a work tree.
  GitRepo? _repo;

  /// The workspace root that was probed for [_repo] — successful or not, so a
  /// non-repo is not re-probed on every workbench notification.
  String? _probedRoot;

  bool _opening = false;
  bool _loading = true;
  String? _error;

  List<UnifiedDiffFile> _files = const [];

  /// The raw diff text was empty and no untracked content replaced it — the
  /// honest "no text changes" rather than a blank panel.
  bool _rawEmpty = false;

  /// The untracked fallback found a binary file: nothing to parse, and a
  /// screenful of replacement characters would read as corruption.
  bool _binary = false;

  /// The repo-relative path a worktree ref shows in its header (the source's
  /// `diff.path`), set once the repo resolves.
  String? _displayPath;

  bool _capExpanded = false;
  Set<int> _expandedFiles = const {};

  @override
  void initState() {
    super.initState();
    widget.workbench.addListener(_onWorkbench);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _runner ??= GitHost.of(context);
    _openRepo();
  }

  @override
  void dispose() {
    widget.workbench.removeListener(_onWorkbench);
    super.dispose();
  }

  /// The workspace root moving means the repository has to be found again and
  /// the diff reloaded against it — the same discipline as the git tab.
  void _onWorkbench() {
    if (widget.workbench.workspaceRoot != _probedRoot) _openRepo();
  }

  Future<void> _openRepo() async {
    final runner = _runner;
    final root = widget.workbench.workspaceRoot;
    if (runner == null || _opening) return;
    if (root == null || widget.tab.diff == null) return;
    if (root == _probedRoot) return;
    _opening = true;
    setState(() => _loading = true);
    try {
      final repo = await openRepo(root, runner: runner);
      if (!mounted || widget.workbench.workspaceRoot != root) return;
      setState(() {
        _repo = repo;
        _probedRoot = root;
        _displayPath = null;
        _files = const [];
        _rawEmpty = false;
        _binary = false;
        // A directory that is not a work tree resolves here and now: nothing
        // further can load, and leaving the spinner up would hide the error
        // behind it forever.
        _error = repo == null ? 'This directory is not a git repository' : null;
        _loading = repo != null;
      });
      if (repo != null) await _load();
    } finally {
      _opening = false;
    }
  }

  Future<void> _refresh() => _load();

  Future<void> _load() async {
    final repo = _repo;
    final ref = widget.tab.diff;
    if (repo == null || ref == null) return;
    setState(() {
      _loading = true;
      _error = null;
      _files = const [];
      _rawEmpty = false;
      _binary = false;
    });
    try {
      switch (ref) {
        case CommitDiff():
          final text = await repo.commitDiff(ref.hashFull);
          _publish(
            repo,
            parseUnifiedDiff(text),
            rawEmpty: text.isEmpty,
            displayPath: null,
          );
        case WorktreeDiff():
          final relative = p.relative(ref.path, from: repo.root);
          var text = await repo.diff(relative, staged: ref.staged);
          if (text.isEmpty) {
            // The requested side is empty — try the OTHER side once: the ref
            // may predate the staged-flag fix, or the change moved sides (a
            // file staged after its tab opened).
            final other = await repo.diff(relative, staged: !ref.staged);
            if (other.isNotEmpty) text = other;
          }
          if (text.isNotEmpty) {
            _publish(repo, parseUnifiedDiff(text), displayPath: relative);
            return;
          }
          if (ref.untracked && !ref.staged) {
            final bytes = await File(ref.path).readAsBytes();
            if (!readsAsText(bytes)) {
              _publish(repo, const [], binary: true, displayPath: relative);
              return;
            }
            final content = const Utf8Decoder(
              allowMalformed: true,
            ).convert(bytes);
            _publish(
              repo,
              [untrackedDiffFile(relative, content)],
              displayPath: relative,
            );
            return;
          }
          _publish(repo, const [], rawEmpty: true, displayPath: relative);
      }
    } on Object catch (error) {
      if (mounted && _repo == repo) {
        setState(() {
          _error = '$error';
          _loading = false;
        });
      }
    }
  }

  /// One complete checkout-derived view, published only if the repo it came
  /// from is still the one on screen.
  void _publish(
    GitRepo repo,
    List<UnifiedDiffFile> files, {
    bool rawEmpty = false,
    bool binary = false,
    String? displayPath,
  }) {
    if (!mounted || _repo != repo) return;
    setState(() {
      _files = files;
      _rawEmpty = rawEmpty;
      _binary = binary;
      if (displayPath != null) _displayPath = displayPath;
      _expandedFiles = defaultExpandedFiles(files);
      _loading = false;
    });
  }

  List<_Row> _flatten() {
    final rows = <_Row>[];
    for (var index = 0; index < _files.length; index++) {
      final file = _files[index];
      rows.add(_PathRow(file, index));
      if (file.binary || !_expandedFiles.contains(index)) continue;
      for (final hunk in file.hunks) {
        rows.add(_HunkRow(hunk));
        for (final line in hunk.lines) {
          rows.add(_LineRow(line));
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final ref = widget.tab.diff;
    if (ref == null) {
      return const _Notice(message: 'This tab has no diff to show.', center: true);
    }
    if (widget.workbench.workspaceRoot == null) {
      return const _Notice(
        message: 'No workspace folder is set, so no diff can be loaded.',
        center: true,
      );
    }
    final title = switch (ref) {
      WorktreeDiff(:final path) => _displayPath ?? p.basename(path),
      CommitDiff(:final hashShort, :final subject) => '$hashShort $subject',
    };
    final tooltip = switch (ref) {
      WorktreeDiff(:final path) => path,
      CommitDiff() => title,
    };
    return CustomScrollView(
      primary: false,
      slivers: [
        SliverToBoxAdapter(
          child: _Header(title: title, tooltip: tooltip, onRefresh: _refresh),
        ),
        if (_loading)
          const SliverToBoxAdapter(child: _Notice(message: 'Loading…', center: true)),
        if (!_loading && _error != null)
          SliverToBoxAdapter(child: _ErrorBox(message: 'Failed to load diff: $_error')),
        if (!_loading && _error == null) ..._bodySlivers(),
      ],
    );
  }

  List<Widget> _bodySlivers() {
    if (_files.isEmpty) {
      if (_binary) {
        return const [
          SliverToBoxAdapter(
            child: _Notice(
              message: 'This looks like a binary file. Nothing here can show it.',
              center: true,
            ),
          ),
        ];
      }
      if (_rawEmpty) {
        return const [
          SliverToBoxAdapter(child: _Notice(message: 'No text changes', center: true)),
        ];
      }
      // A non-empty diff text that parsed to nothing (git noise this parser
      // does not frame): the source renders nothing either.
      return const [];
    }
    final rows = _flatten();
    final hidden = rows.length - _maxDiffRows;
    final capped = hidden > 0 && !_capExpanded;
    final headLines = (_maxDiffRows / 2).ceil();
    final tailLines = _maxDiffRows - headLines;
    final head = capped ? rows.sublist(0, headLines) : rows;
    final tail = capped ? rows.sublist(rows.length - tailLines) : const <_Row>[];
    return [
      SliverList.builder(
        itemCount: head.length,
        itemBuilder: (context, index) => _rowWidget(head[index]),
      ),
      if (hidden > 0)
        SliverToBoxAdapter(
          child: _ExpandToggle(
            hidden: hidden,
            expanded: _capExpanded,
            onTap: () => setState(() => _capExpanded = !_capExpanded),
          ),
        ),
      if (tail.isNotEmpty)
        SliverList.builder(
          itemCount: tail.length,
          itemBuilder: (context, index) => _rowWidget(tail[index]),
        ),
    ];
  }

  Widget _rowWidget(_Row row) {
    return switch (row) {
      _PathRow(:final file, :final index) => _FileHeader(
        file: file,
        expanded: _expandedFiles.contains(index),
        onToggle: () => setState(() {
          final next = {..._expandedFiles};
          if (!next.remove(index)) next.add(index);
          _expandedFiles = next;
        }),
      ),
      _HunkRow(:final hunk) => _HunkHeader(hunk: hunk),
      _LineRow(:final line) => _DiffLineRow(line: line),
    };
  }
}

// ---- The pieces --------------------------------------------------------------

/// `.gitDiffTabHeader`: the change's identity, plus the refresh control. The
/// tab stays mounted while the git panel's staging/discard operations change
/// the very content it shows, which is why the button exists at all.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.tooltip, required this.onRefresh});

  final String title;
  final String tooltip;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12, right: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Tooltip(
              message: tooltip,
              child: Text(
                title,
                style: DswType.xxsStrong12.copyWith(color: color.labelPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _RefreshButton(onTap: onRefresh),
        ],
      ),
    );
  }
}

class _RefreshButton extends StatefulWidget {
  const _RefreshButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: 'Refresh',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _hovered ? color.interactiveBgHover : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(
                LucideIcons.refresh_cw,
                size: 14,
                color: _hovered ? color.labelPrimary : color.labelSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.gitDiffFile`: the chevron + path + old-path + badge row, a button that
/// folds and unfolds the file's hunks.
class _FileHeader extends StatefulWidget {
  const _FileHeader({
    required this.file,
    required this.expanded,
    required this.onToggle,
  });

  final UnifiedDiffFile file;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  State<_FileHeader> createState() => _FileHeaderState();
}

class _FileHeaderState extends State<_FileHeader> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final file = widget.file;
    final tag = diffFileTag(file);
    final from = displayDiffPath(file.oldPath);
    final to = displayDiffPath(file.newPath);
    final expandable = !file.binary && file.hunks.isNotEmpty;
    return MouseRegion(
      cursor: expandable ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: expandable ? widget.onToggle : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _hovered && expandable
                ? color.interactiveBgHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (expandable) ...[
                Icon(
                  widget.expanded ? LucideIcons.chevron_down : LucideIcons.chevron_right,
                  size: 14,
                  color: color.labelTertiary,
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  to,
                  style: DswType.xxsStrong12.copyWith(color: color.labelPrimary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              if (from != to) ...[
                const SizedBox(width: 6),
                Text(
                  '← $from',
                  style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
              if (tag != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: color.borderL2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag,
                    style: DswType.xxxsStrong11.copyWith(
                      color: color.labelSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `.gitDiffHunk`: the `@@ -a,b +c,d @@` header with its section text.
class _HunkHeader extends StatelessWidget {
  const _HunkHeader({required this.hunk});

  final UnifiedDiffHunk hunk;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // Counts recomputed from the parsed rows, as in the source: the header
    // agrees with what is drawn below it even when git's own counts disagree.
    final oldCount = hunk.lines.where((line) => line.oldNum != null).length;
    final newCount = hunk.lines.where((line) => line.newNum != null).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Row(
        children: [
          Text(
            '@@ -${hunk.oldStart},$oldCount +${hunk.newStart},$newCount @@',
            style: DswType.markdownCodeBlockSmall.copyWith(
              color: color.labelSecondary,
            ),
          ),
          if (hunk.header.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hunk.header,
                style: DswType.markdownCodeBlockSmall.copyWith(
                  color: color.labelTertiary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// `.gitDiffLine`: old/new gutters plus the code, tinted by kind.
class _DiffLineRow extends StatelessWidget {
  const _DiffLineRow({required this.line});

  final UnifiedDiffLine line;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (line.kind == DiffLineKind.meta) {
      return Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Text(
          line.text,
          style: DswType.xxxs11.copyWith(
            color: color.labelTertiary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    final (fore, back) = switch (line.kind) {
      DiffLineKind.del => (
        color.stateErrorPrimary,
        color.stateErrorPrimary.withValues(
          alpha: color.stateErrorPrimary.a * 0.12,
        ),
      ),
      DiffLineKind.add => (
        color.stateSuccessPrimary,
        color.stateSuccessPrimary.withValues(
          alpha: color.stateSuccessPrimary.a * 0.12,
        ),
      ),
      _ => (color.labelPrimary, Colors.transparent),
    };
    return ColoredBox(
      color: back,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _gutter(color, line.oldNum),
          _gutter(color, line.newNum),
          Expanded(
            child: Text(
              line.text,
              style: DswType.markdownCodeBlockSmall.copyWith(color: fore),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gutter(DswAlias color, int? num) {
    return SizedBox(
      width: 36,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          num == null ? '' : '$num',
          textAlign: TextAlign.right,
          style: DswType.markdownCodeBlockSmall.copyWith(
            color: color.labelTertiary,
          ),
        ),
      ),
    );
  }
}

/// `.gitDiffExpand` — the brand-coloured toggle that reveals (or re-caps) the
/// rows hidden between the head and tail slices.
class _ExpandToggle extends StatefulWidget {
  const _ExpandToggle({
    required this.hidden,
    required this.expanded,
    required this.onTap,
  });

  final int hidden;
  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_ExpandToggle> createState() => _ExpandToggleState();
}

class _ExpandToggleState extends State<_ExpandToggle> {
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
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
          ),
          child: Center(
            child: Text(
              widget.expanded
                  ? 'Collapse'
                  : 'Expand ${widget.hidden} more rows',
              style: DswType.xxs12.copyWith(color: color.brandPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.gitEmpty` / `.gitPlaceholder` — quiet filler text, as in the git tab.
class _Notice extends StatelessWidget {
  const _Notice({required this.message, this.center = false});

  final String message;

  final bool center;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        message,
        textAlign: center ? TextAlign.center : TextAlign.start,
        style: DswType.xxs12.copyWith(color: color.labelTertiary),
      ),
    );
  }
}

/// `.gitError` — command failures, kept visible.
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
