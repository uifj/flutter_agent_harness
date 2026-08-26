// Git for the source-control tab: the system git, one spawn per call.
//
// A port of `DSH-better-sidebar/src/git.ts`. The source is a webapp backend
// whose panel can address several repositories and linked worktrees at once;
// this app has exactly one workspace root (see `lib/model/workspace.dart`),
// so the port keeps the per-call command shape and porcelain parsing and drops:
//
//   * `worktrees` / `resolveWorktree` — linked checkouts. The source needs a
//     selector for them because a session can be rooted at a clean primary
//     checkout while the agent works in a linked one; here there is no
//     selector to feed, and therefore no seam for a caller to point git at an
//     unrelated repository either.
//   * `repoRoots`' container scan and its caches — with one workspace root,
//     `rev-parse --show-toplevel` is the whole of discovery.
//   * `show` — nothing in this port asks for a file's revision content yet;
//     it is one method away if the diff tab ever wants blame-style views.
//
// Everything runs with `-C <root> --no-pager -c color.ui=false` so output stays
// machine-readable whatever the user's locale and colour config, and commits
// use the user's global identity untouched (never sets user.name/user.email).

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A parsed `git status --porcelain=v1 -z` entry.
class GitStatusEntry {
  const GitStatusEntry({required this.path, required this.xy});

  /// Path relative to the repository root.
  final String path;

  /// Two-letter index/worktree status (X Y), e.g. `'M '`, `' M'`, `'A '`, `'??'`.
  final String xy;

  @override
  String toString() => '$xy $path';
}

/// The source-control panel's snapshot.
class GitStatusResult {
  const GitStatusResult({
    required this.isRepo,
    this.branch,
    this.entries = const [],
    this.truncated = false,
  });

  /// False when the workspace turned out not to be a work tree at all.
  final bool isRepo;

  /// Current branch name, `'HEAD'` when detached, null when not a repo.
  final String? branch;

  final List<GitStatusEntry> entries;

  /// True when the working tree had more rows than the cap; the panel shows a
  /// truncation notice rather than flooding on a huge untracked set.
  final bool truncated;
}

/// One `git log` row.
class GitLogEntry {
  const GitLogEntry({
    required this.hash,
    required this.hashFull,
    required this.subject,
    required this.author,
    required this.date,
    required this.refs,
  });

  /// Short hash (7+ chars, display).
  final String hash;

  /// Full 40-char hash — what revert and cherry-pick address.
  final String hashFull;

  final String subject;

  final String author;

  /// ISO 8601 author date (`%ai`), e.g. `2024-01-01 10:00:00 +0800`.
  final String date;

  /// Ref decorations (`%D`), e.g. `HEAD -> main, origin/main`; '' when none.
  final String refs;

  @override
  String toString() => '$hash $subject';
}

/// One git failure — stderr text as the message.
class GitCommandError implements Exception {
  GitCommandError(this.message, [this.command]);

  final String message;

  /// The arguments the command ran with, for the error's own record.
  final String? command;

  @override
  String toString() => message;
}

/// Runs `git <args>` at [cwd], resolving with stdout or rejecting with
/// [GitCommandError].
///
/// Injectable so the git tab's widget tests drive the whole panel without a
/// repository — the default is a real `git` spawn per call.
typedef GitRunner = Future<String> Function(String cwd, List<String> args);

/// How long one command gets. The commands here are millisecond-scale on a
/// healthy checkout; the budget's real job is bounding a stalled mount, which
/// is what the source's 30s is for too.
const gitTimeout = Duration(seconds: 30);

/// The default runner: spawn git, drain both pipes, enforce the budget.
Future<String> runGit(String cwd, List<String> args) async {
  final Process process;
  try {
    process = await Process.start(
      'git',
      ['-C', cwd, '--no-pager', '-c', 'color.ui=false', ...args],
      workingDirectory: cwd,
      // Merged into the inherited environment: index refreshes the panel never
      // asked for are the source's reason for the flag.
      environment: const {'GIT_OPTIONAL_LOCKS': '0'},
    );
  } on ProcessException catch (error) {
    // A missing git binary is a failed command like any other — the panel
    // shows the message instead of an unhandled async exception.
    throw GitCommandError(error.message, args.join(' '));
  }
  final stdout = _drain(process.stdout);
  final stderr = _drain(process.stderr);
  var timedOut = false;
  try {
    await process.exitCode.timeout(gitTimeout);
  } on TimeoutException {
    timedOut = true;
    process.kill();
    await process.exitCode;
  }
  if (timedOut) {
    throw GitCommandError(
      'git ${args.isEmpty ? '' : args.first} timed out',
      args.join(' '),
    );
  }
  final code = await process.exitCode;
  if (code != 0) {
    final message = (await stderr).trim();
    throw GitCommandError(
      message.isEmpty ? 'git exited with $code' : message,
      args.join(' '),
    );
  }
  return stdout;
}

Future<String> _drain(Stream<List<int>> stream) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    bytes.add(chunk);
  }
  // Malformed-tolerant on purpose: a diff of binary content still has to arrive
  // as text the panel can render a notice over, not as an exception.
  return utf8.decode(bytes.takeBytes(), allowMalformed: true);
}

/// Upper bound on status rows the panel ships. Beyond this the result is
/// truncated (with [GitStatusResult.truncated]) so a pathological untracked
/// set cannot flood the tab — the source's issue #369.
const gitStatusLimit = 2000;

/// Parse porcelain v1 `-z` output (rename/copy pairs collapse to one row).
///
/// Pure, so the whole framing vocabulary is testable without a repository.
List<GitStatusEntry> parsePorcelainZ(String output) {
  final entries = <GitStatusEntry>[];
  final tokens = output.split('\x00');
  var index = 0;
  while (index < tokens.length) {
    final token = tokens[index];
    index += 1;
    if (token.length < 4) continue;
    final xy = token.substring(0, 2);
    entries.add(GitStatusEntry(path: token.substring(3), xy: xy));
    // Rename/copy entries carry the ORIGIN path as the next NUL field; the new
    // path (the file as it exists now) is the one worth displaying.
    if ((xy[0] == 'R' || xy[0] == 'C') &&
        index < tokens.length &&
        tokens[index].isNotEmpty) {
      index += 1;
    }
  }
  return entries;
}

/// Parse `git log --pretty=format:%h<x1f>%s<x1f>%an<x1f>%ai<x1f>%H<x1f>%D` rows.
List<GitLogEntry> parseLogLines(String output) {
  final rows = <GitLogEntry>[];
  for (final line in output.split('\n')) {
    if (line.isEmpty) continue;
    final fields = line.split('\x1f');
    if (fields.length < 2) continue;
    rows.add(
      GitLogEntry(
        hash: fields[0],
        subject: fields[1],
        author: fields.length > 2 ? fields[2] : '',
        date: fields.length > 3 ? fields[3] : '',
        hashFull: fields.length > 4 ? fields[4] : fields[0],
        refs: fields.length > 5 ? fields[5] : '',
      ),
    );
  }
  return rows;
}

/// The repository containing [cwd], or null when there is none.
///
/// One rev-parse decides it: `--show-toplevel` fails exactly when the directory
/// is not inside a work tree, which is the same answer the source's two-step
/// `isGitRepo` + root resolves to, at half the spawns.
Future<GitRepo?> openRepo(String cwd, {GitRunner? runner}) async {
  final run = runner ?? runGit;
  final String root;
  try {
    root = (await run(cwd, const ['rev-parse', '--show-toplevel'])).trim();
  } on GitCommandError {
    return null;
  }
  return root.isEmpty ? null : GitRepo(root, runner: run);
}

/// One repository, addressed by its top-level directory.
class GitRepo {
  GitRepo(this.root, {GitRunner? runner}) : _run = runner ?? runGit;

  /// The repository's top-level directory, as git reported it.
  final String root;

  final GitRunner _run;

  Future<String> _git(List<String> args) => _run(root, args);

  /// The current branch name, `'HEAD'` when detached.
  Future<String> branch() async =>
      (await _git(const ['rev-parse', '--abbrev-ref', 'HEAD'])).trim();

  /// Branch names, current first.
  Future<List<String>> branches() async {
    final current = await branch();
    final raw = await _git(
      const ['for-each-ref', '--format=%(refname:short)', 'refs/heads'],
    );
    final names = raw
        .split('\n')
        .where((line) => line.isNotEmpty)
        .toList();
    return names.contains(current) ? names : [current, ...names];
  }

  /// Switch to an existing branch.
  Future<void> checkout(String branch) => _git(['checkout', branch]);

  /// Working-tree status, untracked included, truncated past the cap.
  Future<GitStatusResult> status() async {
    final raw = await _git(
      const ['status', '--porcelain=v1', '-z', '--untracked-files=all'],
    );
    final parsed = parsePorcelainZ(raw);
    final truncated = parsed.length > gitStatusLimit;
    String branch = 'HEAD';
    try {
      branch = await this.branch();
    } on GitCommandError {
      // A repository with no commits yet has no branch name; the source's
      // `.catch(() => 'HEAD')` for exactly this.
    }
    return GitStatusResult(
      isRepo: true,
      branch: branch,
      entries: truncated ? parsed.sublist(0, gitStatusLimit) : parsed,
      truncated: truncated,
    );
  }

  /// Diff text of the worktree (unstaged) or the index (staged) for [path], or
  /// the whole tree when null.
  Future<String> diff(String? path, {bool staged = false}) {
    final args = ['diff', '--no-ext-diff', '--no-color', '-U3'];
    if (staged) args.add('--cached');
    if (path != null) args.addAll(['--', path]);
    return _git(args);
  }

  /// Stage [path] (everything when null).
  Future<void> stage(String? path) => _git(
    path == null ? const ['add', '-A'] : ['add', '-A', '--', path],
  );

  /// Unstage [path] (everything when null).
  Future<void> unstage(String? path) => _git(
    path == null ? const ['reset', '-q'] : ['reset', '-q', '--', path],
  );

  /// Commit the staged changes with [message]; the global identity untouched.
  Future<void> commit(String message) => _git(['commit', '-m', message]);

  /// Recent history, newest first, pageable via [skip].
  Future<List<GitLogEntry>> log({int count = 30, int skip = 0}) async {
    final raw = await _git([
      'log', '-n', '$count', '--skip', '$skip', '--decorate=short',
      '--pretty=format:%h\x1f%s\x1f%an\x1f%ai\x1f%H\x1f%D',
    ]);
    return parseLogLines(raw);
  }

  /// Full patch of one commit. Merge commits diff against the first parent, so
  /// a history click always has content.
  Future<String> commitDiff(String hashFull) => _git([
    'show', '--no-ext-diff', '--no-color', '--format=', '-m', '--first-parent',
    hashFull,
  ]);

  /// Discard the worktree changes of [path]; the index is untouched.
  Future<void> discard(String path) => _git(['checkout', '--', path]);

  /// Revert one commit onto the current branch with an auto-generated message.
  Future<void> revert(String hashFull) =>
      _git(['revert', '--no-edit', hashFull]);

  /// Cherry-pick one commit onto the current branch.
  Future<void> cherryPick(String hashFull) => _git(['cherry-pick', hashFull]);
}
