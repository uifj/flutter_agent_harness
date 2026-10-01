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
  final Map<String, String> _errors = {};

  /// Which repository each asked path turned out to be inside.
  ///
  /// The panel asks about the repository's top level; a file tree can be rooted
  /// anywhere below it. Keying by whichever string arrived first would hand that
  /// repository two readings and two processes — the split this store exists to
  /// prevent — so an answer is filed under the top level git reported, and every
  /// path that asked about it is remembered as an alias for that key.
  final Map<String, String> _asked = {};

  String _key(String asked) => _asked[asked] ?? asked;

  /// The last reading for [root], or null while none has landed.
  ///
  /// Views paint from this and listen to the notifier; only [read] runs git.
  GitStatusResult? reading(String root) => _readings[_key(root)];

  /// Whether [root] has a reading newer than [freshness].
  bool isFresh(String root) {
    final at = _fetchedAt[_key(root)];
    return at != null && _now().difference(at) < freshness;
  }

  /// The reading for [root], fetched when it is missing, stale, or [force].
  ///
  /// Concurrent calls for the same root share one run, so the panel's tick and a
  /// tree that just mounted cannot start two `git status` processes.
  Future<GitStatusResult> read(String root, {bool force = false}) {
    final key = _key(root);
    final existing = _inFlight[key];
    if (existing != null && !force) return existing;
    if (!force && _readings[key] != null && isFresh(root)) {
      return Future.value(_readings[key]);
    }
    final run = _fetch(root);
    _inFlight[key] = run;
    return run.whenComplete(() => _inFlight.remove(key));
  }

  Future<GitStatusResult> _fetch(String asked) async {
    final result = await _attempt(asked);
    // File the answer under the repository's own top level, so the next reader —
    // asking about any folder inside it — hits this reading. `rev-parse` failing
    // means there is no top level, and that answer stays keyed by the path that
    // asked. The in-flight slot is released under the pre-fetch key it was taken
    // under; two *simultaneous* cold asks from different folders can still each
    // run, which is the price of not knowing the top level before asking.
    final top = result.root ?? asked;
    _asked[asked] = top;
    _adopt(top, result);
    return result;
  }

  Future<GitStatusResult> _attempt(String root) async {
    try {
      final repo = await openRepo(root, runner: _runner);
      if (repo == null) {
        _errors.remove(root);
        return const GitStatusResult(isRepo: false);
      }
      final status = await repo.status();
      _errors.remove(root);
      return status;
    } on GitCommandError catch (error) {
      // The panel asked on purpose and shows the message, so the failure is kept
      // for it rather than flattened into "not a repository".
      _errors[root] = error.message;
      return _readings[root] ?? const GitStatusResult(isRepo: false);
    } on Object {
      // No git binary, a directory that vanished: "there is no status" is the
      // answer, and it is cached like any other.
      return _readings[root] ?? const GitStatusResult(isRepo: false);
    }
  }

  /// Why the last read for [root] failed, or null. Only the panel reads this —
  /// the tree stays silent, because it never asked. Looked up by the asking path
  /// as well as the repository key, because a failure can happen before either
  /// is known.
  String? errorFor(String root) => _errors[_key(root)] ?? _errors[root];

  /// After a stage / commit / discard / checkout: the next read must not be
  /// answered from the cache the action just invalidated.
  void invalidate(String root) {
    _fetchedAt.remove(_key(root));
  }

  void _adopt(String root, GitStatusResult result) {
    _readings[root] = result;
    _fetchedAt[root] = _now();
    notifyListeners();
  }
}
