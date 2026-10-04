// The transcript a compression summarizes (ADR-0061): the conversation as
// the user saw it, minus the parts that would blow the summarizer's own
// window. Pure Dart over the transcript's node types — the controller hands
// it its nodes, the runtime receives plain text, and neither learns the
// other's shape.

import 'conversation.dart';

/// Per-message and total caps for the summarizer's source text, in
/// characters — kelivo runs the same two-tier window (2000/12000). A message
/// that overflows its cap is truncated with a marker rather than dropped:
/// the model should know there was more.
const compressionPerMessageCap = 800;
const compressionTotalCap = 12000;

/// The whole transcript as one clipboard payload (ADR-0066): every user and
/// assistant turn in order, joined by newlines — the compressor's source
/// assembly, uncapped and prefixed by speaker.
String transcriptTextOf(List<ConversationNode> nodes) {
  final lines = <String>[];
  for (final node in nodes) {
    if (node is UserMessageNode && node.text.trim().isNotEmpty) {
      lines.add('user: ${node.text.trim()}');
    } else if (node is AssistantMessageNode && node.text.trim().isNotEmpty) {
      lines.add('assistant: ${node.text.trim()}');
    }
  }
  return lines.join('\n');
}

/// Builds the summarizer's source text from the transcript's user and
/// assistant turns. Tool calls are excluded (the S1 boundary, ADR-0061):
/// they are the largest and least conversational part of a transcript.
/// Empty when there is nothing to summarize.
String compressionTranscriptOf(
  List<ConversationNode> nodes, {
  int perMessageCap = compressionPerMessageCap,
  int totalCap = compressionTotalCap,
}) {
  final lines = <String>[];
  var total = 0;
  for (final node in nodes) {
    final String text;
    if (node is UserMessageNode) {
      text = node.text.trim();
    } else if (node is AssistantMessageNode) {
      text = node.text.trim();
    } else {
      continue;
    }
    if (text.isEmpty) continue;
    final body = text.length > perMessageCap
        ? '${text.substring(0, perMessageCap)}…(truncated)'
        : text;
    final speaker = node is UserMessageNode ? 'user' : 'assistant';
    final line = '$speaker: $body';
    if (total + line.length > totalCap) {
      lines.add('…(earlier turns omitted)');
      break;
    }
    lines.add(line);
    total += line.length;
  }
  return lines.join('\n');
}
