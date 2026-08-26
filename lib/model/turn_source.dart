// What the state layer needs from a turn runner.
//
// `AgentRuntime` is the only implementation, and this is the shape of the narrow
// point between it and everything above: plain values in, `TurnEvent`s out, no
// Genkit types anywhere in the signature. Naming it separately means the state
// layer compiles — and tests run — without the runtime, its plugins, or a
// network stack.

import 'conversation.dart';
import 'turn_event.dart';

abstract interface class TurnSource {
  /// Null until the current conversation has been persisted.
  String? get sessionId;

  /// Sends [text] and streams the turn. The stream always ends with a
  /// [TurnFinished], including on failure, and is single-subscription.
  Stream<TurnEvent> send(String text);

  /// Answers a pending approval and streams the rest of the paused turn.
  Stream<TurnEvent> respondToApproval({
    required String ref,
    required bool approved,
  });

  /// Asks for the running turn to stop. Best effort — see the cancellation notes
  /// in the runtime.
  void stop();

  /// Drops the current conversation, leaving it on disk.
  void startNewSession();

  /// Restores a persisted conversation and returns its transcript.
  Future<List<ConversationNode>> openSession(String id);

  /// The persisted conversations, newest first.
  Future<List<SessionSummary>> listSessions();
}
