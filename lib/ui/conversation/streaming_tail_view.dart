// The live tail of the running message.
//
// This is the view half of the streaming split: it subscribes to the two
// notifiers in `StreamingTail` directly, so a token delta repaints this subtree
// and nothing else. The transcript around it is driven by the conversation
// controller, which stays quiet for the whole message.
//
// When the message ends, the controller freezes the tail onto its node and the
// list rebuilds once, replacing this view with a settled `MessageItem`.

import 'package:flutter/material.dart';

import '../../state/streaming_tail.dart';
import 'assistant_body.dart';

class StreamingTailView extends StatelessWidget {
  const StreamingTailView({super.key, required this.tail});

  final StreamingTail tail;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: tail.reasoning,
    builder: (context, reasoning, _) => ValueListenableBuilder<String>(
      valueListenable: tail.text,
      builder: (context, text, _) =>
          AssistantBody(reasoning: reasoning, text: text, streaming: true),
    ),
  );
}
