// The workspace filesystem's revision counter.
//
// A port of IstiN/flutter_agent_harness's `AgentService.fsRevision`: every
// successful agent write bumps it, and the file tree listens — that is how the
// browser learns the agent changed files WITHOUT polling, and without paying for
// a `Directory.watch` FSEvents stream per expanded folder. The revision carries
// no payload on purpose: which directory changed is derivable only by re-listing,
// so the counter says "something under the workspace changed" and the listener
// decides how much to re-read.
//
// A global, because there is exactly one workspace filesystem per process and two
// owners — the tools that bump it and the tabs that listen — with no object
// between them that both would already hold. Tests reset it to zero in setUp.
//
// It lives here, and it is Dart-only, for one reason (ADR-0015): `lib/genkit/`
// bumps it, and the runtime has to stay compilable without Flutter — that is what
// lets `dart run spike/runtime_smoke.dart` drive the whole tool loop from the
// command line. `lib/state/` was its previous home and it was a
// `ValueNotifier` there, which dragged `package:flutter` (and through it
// `dart:ui`) into the runtime's import graph. `lib/model/` is the one layer both
// sides may reach, and invariant 2 is what keeps it Flutter-free.
//
// The consequence worth knowing: this is not a `Listenable`. A widget that wants
// to rebuild on it adds a listener and calls `setState`, which is what
// `file_tree_tab.dart` already does.

/// The counter itself. One instance, named [fsRevision].
class FsRevision {
  int _value = 0;
  final List<void Function()> _listeners = [];

  int get value => _value;

  /// Notifies every listener of the new value. The snapshot is what lets a
  /// listener remove itself while being dispatched — a re-list is exactly that.
  void bump() {
    _value++;
    for (final listener in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  /// Zeroes the counter without notifying anyone. Tests only — see
  /// [resetFsRevisionForTest].
  void reset() => _value = 0;
}

final fsRevision = FsRevision();

/// The bump itself. Called by the write/edit tools after the file lands, and by
/// a rewind after it restores one.
void bumpFsRevision() => fsRevision.bump();

/// Resets the counter — tests only, so a bump from a previous test cannot read
/// as this one's.
void resetFsRevisionForTest() => fsRevision.reset();
