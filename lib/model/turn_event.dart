// The application's view of a running turn.
//
// `lib/genkit/agent_runtime.dart` projects the runtime's chunk stream into these
// events; everything above it (state, UI) sees only this file. Like
// `conversation.dart`, nothing here imports `package:genkit`.

import 'conversation.dart';

/// How a turn ended.
enum TurnOutcome {
  /// The model finished its answer.
  completed,

  /// A tool interrupted for approval; the turn is paused, not over. Resume with
  /// `AgentRuntime.respondToApproval`.
  awaitingApproval,

  /// The user pressed stop.
  cancelled,

  /// The turn hit the model's output limit.
  truncated,

  /// Something threw, or the provider refused.
  failed,
}

/// One observable step of a turn.
sealed class TurnEvent {
  const TurnEvent();
}

/// Streamed answer text.
///
/// [messageIndex] is the runtime's own index for the message being built. It
/// changes when the model starts a new message — which happens on every trip
/// around the tool loop — so it is what tells the transcript to open a new
/// assistant bubble rather than keep appending to the last one.
class TextDelta extends TurnEvent {
  const TextDelta({required this.text, required this.messageIndex});

  final String text;
  final int messageIndex;
}

/// Streamed chain-of-thought, on its own channel (DeepSeek's reasoner models).
class ReasoningDelta extends TurnEvent {
  const ReasoningDelta({required this.text, required this.messageIndex});

  final String text;
  final int messageIndex;
}

/// The model asked for a tool call. Emitted once per [ref], even though the
/// runtime may stream the same request twice.
class ToolCallRequested extends TurnEvent {
  const ToolCallRequested({
    required this.ref,
    required this.name,
    required this.arguments,
  });

  final String ref;
  final String name;
  final Map<String, dynamic> arguments;
}

class ToolCallSucceeded extends TurnEvent {
  const ToolCallSucceeded({required this.ref, required this.output});

  final String ref;
  final Object? output;
}

class ToolCallFailed extends TurnEvent {
  const ToolCallFailed({required this.ref, required this.message});

  final String ref;
  final String message;
}

/// A tool paused itself to ask permission. The turn will end
/// [TurnOutcome.awaitingApproval] and wait for a decision.
class ApprovalRequired extends TurnEvent {
  const ApprovalRequired(this.request);

  final ApprovalRequest request;
}

/// Always the last event of a turn, whatever the outcome.
class TurnFinished extends TurnEvent {
  const TurnFinished({
    required this.outcome,
    this.sessionId,
    this.snapshotId,
    this.errorMessage,
    this.usage,
  });

  final TurnOutcome outcome;

  /// Set once the runtime has persisted a snapshot, so a brand-new conversation
  /// only becomes listable after its first turn.
  final String? sessionId;
  final String? snapshotId;

  /// Present when [outcome] is [TurnOutcome.failed].
  final String? errorMessage;

  /// What this turn cost, when the runtime could measure it. Null when the
  /// turn never reached a model — the stats line treats that as "no new
  /// figures", not as zeros.
  final TurnUsage? usage;
}

/// The measurable cost of one turn, dsh's `sessionStats` unit collapsed into
/// the one payload this app's single-process runtime can fill. Wall time and
/// TTFT are runtime-measured (dsh measures `step/start → assistant/message`
/// the same way); token counts are absent because Genkit's `AgentOutput`
/// does not surface the provider's `usage` block.
class TurnUsage {
  const TurnUsage({
    required this.wallMs,
    this.ttftMs,
  });

  /// Turn entry to finish, in milliseconds.
  final int wallMs;

  /// Send to first streamed token, when a token ever arrived.
  final int? ttftMs;
}
