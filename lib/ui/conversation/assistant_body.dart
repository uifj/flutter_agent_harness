// The assistant's side of a turn: reasoning above, prose below.
//
// Shared by the settled node in `message_item.dart` and the live tail in
// `streaming_tail_view.dart`, so both spell the composition the same way. The
// 16px block gap is `AssistantMarkdown.module.css:14-18`.

import 'package:flutter/material.dart';

import 'assistant_markdown.dart';
import 'reasoning_row.dart';

class AssistantBody extends StatelessWidget {
  const AssistantBody({
    super.key,
    required this.reasoning,
    required this.text,
    this.streaming = false,
  });

  final String reasoning;
  final String text;

  /// Whether more of this message may still arrive.
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final hasReasoning = reasoning.isNotEmpty;
    final hasText = text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasReasoning) ReasoningRow(text: reasoning, running: streaming),
        // The gap belongs between the two blocks, not around them: a body with
        // only one block must not carry it.
        if (hasReasoning && hasText) const SizedBox(height: 16),
        if (hasText) AssistantMarkdown(text, streaming: streaming),
      ],
    );
  }
}
