// One settled entry in the transcript.
//
// A port of `MessageItem.module.css`. Every node type the app models gets its
// row here; the running message is not one of them — `chat_view.dart` routes
// that to `StreamingTailView` instead, which is why nothing in this file touches
// the streaming tail.

import 'package:flutter/material.dart';

import '../../model/conversation.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/state_dot.dart';
import '../tool/tool_card.dart';
import 'assistant_body.dart';

class MessageItem extends StatelessWidget {
  const MessageItem({super.key, required this.node});

  final ConversationNode node;

  @override
  Widget build(BuildContext context) => switch (node) {
    UserMessageNode(:final text) => _UserBubble(text: text),
    AssistantMessageNode(:final text, :final reasoning) => AssistantBody(
      reasoning: reasoning,
      text: text,
    ),
    ToolCallNode() => ToolCard(node: node as ToolCallNode),
    ErrorNode(:final message) => _TurnError(message: message),
  };
}

/// `MessageItem.module.css:4-29` (Figma User_Bubble/message_container
/// 659:38813): a right-aligned stack capped well short of the column, so the
/// reader's own words read as an aside rather than as body text.
class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        // The stack is right-aligned; the 6px gap below it belongs to the icon
        // actions, which this build does not have yet.
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            // `max-width: min(525px, 82%)`: the pixel cap governs at the full
            // column width, the percentage takes over once the window narrows.
            constraints: BoxConstraints(
              maxWidth: constraints.maxWidth * 0.82 < 525
                  ? constraints.maxWidth * 0.82
                  : 525,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color.bubble,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                // 10 + 24 + 10: the 44px single-line bubble the source calls out.
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: SelectableText(
                  text,
                  style: DswType.base16.copyWith(color: color.labelPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `MessageItem.module.css:218-245`: a failed turn stays in the transcript as a
/// quiet 13/20 row rather than surfacing as a dialog, so the record of what
/// happened is complete.
class _TurnError extends StatelessWidget {
  const _TurnError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final body = DswType.xs13;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The dot's own 10px column, nudged onto the first line's baseline.
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: StateDot(state: StateDotState.error),
          ),
          const SizedBox(width: 8),
          Expanded(child: _copy(color, body)),
        ],
      ),
    );
  }

  /// Title and message share one paragraph so the message wraps under the title
  /// rather than into a second column.
  Widget _copy(DswAlias color, TextStyle body) => SelectableText.rich(
    TextSpan(
      children: [
        TextSpan(
          text: 'This turn failed',
          style: body.copyWith(
            color: color.stateErrorPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        // The 6px the source puts after the title, as a space that cannot be
        // wrapped away from it.
        TextSpan(text: '\u2002', style: body),
        TextSpan(text: message, style: body.copyWith(color: color.labelSecondary)),
      ],
    ),
  );
}
