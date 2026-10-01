// One `git status`, two readers (ADR-0043).
//
// The source-control panel and the file tree want the same answer: which paths
// are dirty. Before this, `GitRepository.status()` had exactly one caller — the
// panel — which kept the result in its own State and refreshed it from its own
// timer. A tree that asked for itself would have been a second poll and a second
// copy of the same fact, which is the defect class ADR-0023 named for motion and
// ADR-0035 for a tool result.
//
// Three rules hold it together:
//   * One interval. [freshness] is the app's only git-poll number; callers ask for
//     a reading and the store decides whether it is stale. The panel still owns
//     *when* it cares (it only ticks while it is the visible tab); the store owns
//     *how long is fresh*.
//   * One run at a time. Two readers arriving on a cold cache share one process.
//   * A missing repository is a cached answer too. `isRepo: false` is stored, so a
//     non-repository workspace pays one `rev-parse` and never again until something
//     invalidates it — the tree must not nag git on every rebuild.

import 'package:flutter/foundation.dart';

import '../host/git.dart';

/// The cache, keyed by repository root.
class GitStatusStore extends ChangeNotifier {
  GitStatusStore({required GitRunner runner, DateTime Function()? clock})
    : _runner = runner,
      _now = clock ?? DateTime.now;

  /// How long a reading counts as fresh. This number used to be a literal inside
  /// the git tab's `Timer.periodic`.
  static const freshness = Duration(seconds: 2);

  final GitRunner _runner;
  final DateTime Function() _now;

  final Map<String, GitStatusResult> _readings = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, Future<GitStatusResult>> _inFlight = {};

  /// The last reading for [root], or null while none has landed.
  ///
  /// Views paint from this and listen to the notifier; only [read] runs git.
  GitStatusResult? reading(String root) => _readings[root];

  /// Whether [root] has a reading newer than [freshness].
  bool isFresh(String root) {
    final at = _fetchedAt[root];
    return at != null && _now().difference(at) < freshness;
  }

  /// The reading for [root], fetched when it is missing, stale, or [force].
  ///
  /// Concurrent calls for the same root share one run, so the panel's tick and a
  /// tree that just mounted cannot start two `git status` processes.
  Future<GitStatusResult> read(String root, {bool force = false}) {
    final existing = _inFlight[root];
    if (existing != null && !force) return existing;
    if (!force && _readings[root] != null && isFresh(root)) {
      return Future.value(_readings[root]);
    }
    final run = _fetch(root);
    _inFlight[root] = run;
    return run.whenComplete(() => _inFlight.remove(root));
  }

  Future<GitStatusResult> _fetch(String root) async {
    final result = await _attempt(root);
    _adopt(root, result);
    return result;
  }

  Future<GitStatusResult> _attempt(String root) async {
    try {
      final repo = await openRepo(root, runner: _runner);
      if (repo == null) return const GitStatusResult(isRepo: false);
      return await repo.status();
    } on Object {
      // Not a work tree, no git binary, a repository mid-write: "there is no
      // status" is the answer, and it is cached like any other. The panel that
      // asked on purpose still shows its own error box — it has the message,
      // this store only keeps the fact.
      return const GitStatusResult(isRepo: false);
    }
  }

  /// After a stage / commit / discard / checkout: the next read must not be
  /// answered from the cache the action just invalidated.
  void invalidate(String root) {
    _fetchedAt.remove(root);
  }

  void _adopt(String root, GitStatusResult result) {
    _readings[root] = result;
    _fetchedAt[root] = _now();
    notifyListeners();
  }
}
