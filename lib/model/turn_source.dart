// What the state layer needs from a turn runner.
//
// `AgentRuntime` is the only implementation, and this is the shape of the narrow
// point between it and everything above: plain values in, `TurnEvent`s out, no
// Genkit types anywhere in the signature. Naming it separately means the state
// layer compiles — and tests run — without the runtime, its plugins, or a
// network stack.

import 'approval_mode.dart';
import 'attached_image.dart';
import 'conversation.dart';
import 'queued_input.dart';
import 'turn_event.dart';

abstract interface class TurnSource {
  /// Null until the current conversation has been persisted.
  String? get sessionId;

  /// Sends [text], with [images] riding the same message, and streams the
  /// turn. The returned stream always ends with a [TurnFinished], including on
  /// failure, and is single-subscription.
  Stream<TurnEvent> send(String text, {List<AttachedImage> images});

  /// Answers a pending approval and streams the rest of the paused turn.
  Stream<TurnEvent> respondToApproval({
    required String ref,
    required bool approved,
  });

  /// Delivers the user's answers to a pending ask_user call (ADR-0059) and
  /// streams the rest of the paused turn. The answers ARE the tool result —
  /// the resume uses genkit's respond path, not a restart.
  Stream<TurnEvent> respondToAskUser({
    required String ref,
    required Map<String, Object?> answers,
  });

  /// Summarizes [transcript] for a context compression (ADR-0061) with one
  /// standalone model call. Throws on failure — the caller surfaces it.
  Future<String> summarizeForCompression(String transcript);

  /// Arms the compression summary the next send of this session will carry
  /// (ADR-0061). Call after [startNewSession]; the runtime clears it on any
  /// other session change.
  void setPendingSummary(String summary);

  /// Hands [input] to the running turn, to be read at its next model call.
  ///
  /// Returns false when nothing is running — the caller then has to deliver it
  /// itself, as a turn. A true return is not a promise the model read it yet:
  /// a turn that is only streaming an answer never makes another model call, so
  /// what it holds comes back out of [takeUndeliveredGuides].
  bool guide(QueuedInput input);

  /// Guides a running turn never reached, oldest first; emptied by reading.
  List<QueuedInput> takeUndeliveredGuides();

  /// Sets how gated tools behave from the next call. Live — no rebuild.
  set approvalMode(ApprovalMode mode);

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

/// What a side-chat thread needs from its runner.
///
/// The runtime's side agent adapter implements this; the side-chat controller
/// knows nothing about Genkit, which keeps the same narrow point [TurnSource]
/// draws between the state layer and the runtime.
abstract interface class SideTurnSource {
  /// Sends [text] and streams the answer as text deltas, ending with a
  /// [TurnFinished]. Single-subscription.
  Stream<TurnEvent> send(String text);

  /// Drops the thread's context — the next send starts a fresh exchange.
  void reset();
}
