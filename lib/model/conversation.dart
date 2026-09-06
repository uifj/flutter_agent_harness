// The application's own conversation model.
//
// Nothing here imports `package:genkit`. That is the point: `lib/genkit/` owns
// every Genkit type and hands the rest of the app these plain values instead, so
// a 0.x breaking change lands in two files rather than across the UI. The plan
// calls this "单点收窄" — the single narrow point.
//
// A grep for `package:genkit` should only ever match `lib/genkit/`.

import 'attached_image.dart';

/// Where a tool call has got to.
enum ToolStatus {
  /// The model asked for the call and it is executing.
  running,

  /// The tool interrupted itself to ask the user; see [ToolCallNode.approval].
  awaitingApproval,

  /// Returned normally.
  succeeded,

  /// Threw, or was reported as an error by the runtime.
  failed,

  /// The user rejected the approval request, so the tool never ran.
  denied,
}

/// Whether [status] is one the call never leaves. Pauses are not settles: a
/// call waiting on the user is still mid-flight, and its clock keeps running.
extension ToolStatusSettled on ToolStatus {
  bool get isSettled => switch (this) {
    ToolStatus.succeeded || ToolStatus.failed || ToolStatus.denied => true,
    ToolStatus.running || ToolStatus.awaitingApproval => false,
  };
}

/// A pending approval, surfaced when a tool interrupts to ask permission.
///
/// [ref] is the tool call's identity and is what the runtime needs back in order
/// to resume, so it must survive the round trip through the UI untouched.
class ApprovalRequest {
  const ApprovalRequest({
    required this.ref,
    required this.toolName,
    required this.arguments,
    this.details = const {},
  });

  final String ref;
  final String toolName;
  final Map<String, dynamic> arguments;

  /// Whatever the tool passed to its interrupt call — free-form, for the panel
  /// to explain what is about to happen.
  final Map<String, dynamic> details;
}

/// One entry in the transcript.
///
/// Built by projecting the runtime's event stream, never read back off the
/// runtime: the spike established that the runtime's own in-memory message list
/// omits tool turns, so it cannot serve as the transcript.
sealed class ConversationNode {
  const ConversationNode({required this.id});

  /// Stable across rebuilds, so `ListView` keys and scroll positions hold.
  final String id;
}

class UserMessageNode extends ConversationNode {
  const UserMessageNode({
    required super.id,
    required this.text,
    this.images = const [],
  });

  final String text;

  /// The images riding this message, in pick order. Empty for text-only sends.
  final List<AttachedImage> images;
}

class AssistantMessageNode extends ConversationNode {
  const AssistantMessageNode({
    required super.id,
    required this.text,
    this.reasoning = '',
    this.isStreaming = false,
  });

  final String text;

  /// Reasoning arrives on its own channel (DeepSeek's reasoner models), so it is
  /// kept apart from [text] rather than concatenated.
  final String reasoning;

  /// True while this is the node the streaming tail is appending to. The tail
  /// itself lives in a separate notifier; this only tells the view which node
  /// should defer to it.
  final bool isStreaming;

  AssistantMessageNode copyWith({
    String? text,
    String? reasoning,
    bool? isStreaming,
  }) => AssistantMessageNode(
    id: id,
    text: text ?? this.text,
    reasoning: reasoning ?? this.reasoning,
    isStreaming: isStreaming ?? this.isStreaming,
  );
}

class ToolCallNode extends ConversationNode {
  const ToolCallNode({
    required super.id,
    required this.name,
    required this.arguments,
    required this.status,
    this.output,
    this.errorMessage,
    this.approval,
    this.startedAt,
    this.finishedAt,
  });

  final String name;
  final Map<String, dynamic> arguments;
  final ToolStatus status;

  /// The tool's return value, decoded. `null` until it returns.
  final Object? output;

  final String? errorMessage;

  /// Set only while [status] is [ToolStatus.awaitingApproval].
  final ApprovalRequest? approval;

  /// When the call began, or null when the transcript was rebuilt from a
  /// persisted snapshot, which does not record times. Surfaces that read it
  /// (the sub-agent tab's elapsed clock) fall back to showing nothing rather
  /// than to a zero.
  final DateTime? startedAt;

  /// When the call settled — see [ToolStatusSettled]. Null while it runs.
  final DateTime? finishedAt;

  ToolCallNode copyWith({
    ToolStatus? status,
    Object? output,
    String? errorMessage,
    ApprovalRequest? approval,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool clearApproval = false,
  }) => ToolCallNode(
    id: id,
    name: name,
    arguments: arguments,
    status: status ?? this.status,
    output: output ?? this.output,
    errorMessage: errorMessage ?? this.errorMessage,
    approval: clearApproval ? null : (approval ?? this.approval),
    startedAt: startedAt ?? this.startedAt,
    finishedAt: finishedAt ?? this.finishedAt,
  );
}

/// A turn that ended badly — shown inline rather than as a dialog, so the
/// transcript stays a complete record of what happened.
class ErrorNode extends ConversationNode {
  const ErrorNode({required super.id, required this.message});

  final String message;
}

/// A row in the session list.
///
/// The snapshot store has no listing API, so this is assembled from the pointer
/// files it writes; [title] is absent until the session has been opened once,
/// because deriving it means reading the snapshot itself.
class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.updatedAt,
    this.title,
  });

  final String id;
  final DateTime updatedAt;
  final String? title;

  SessionSummary withTitle(String? title) =>
      SessionSummary(id: id, updatedAt: updatedAt, title: title);
}
