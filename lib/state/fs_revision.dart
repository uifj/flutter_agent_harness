// The workspace filesystem's revision counter.
//
// A port of IstiN/flutter_agent_harness's `AgentService.fsRevision`
// (`ValueListenable<int>`): every successful agent write bumps it, and the
// file tree listens — that is how the browser learns the agent changed files
// WITHOUT polling, and without paying for a `Directory.watch` FSEvents
// stream per expanded folder. The revision carries no payload on purpose:
// which directory changed is derivable only by re-listing, so the counter
// says "something under the workspace changed" and the listener decides how
// much to re-read.
//
// A global, because there is exactly one workspace filesystem per process
// and two owners — the tools that bump it and the tabs that listen — with no
// object between them that both would already hold. Tests reset it to zero
// in setUp.

import 'package:flutter/foundation.dart';

/// Bumped once per successful agent write or edit. See the file comment.
final fsRevision = ValueNotifier<int>(0);

/// The bump itself. Called by the write/edit tools after the file lands.
void bumpFsRevision() => fsRevision.value++;

/// Resets the counter — tests only, so a bump from a previous test cannot
/// read as this one's.
void resetFsRevisionForTest() => fsRevision.value = 0;
