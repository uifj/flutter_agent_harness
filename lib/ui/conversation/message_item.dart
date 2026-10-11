// One settled entry in the transcript.
//
// A port of `MessageItem.module.css`. Every node type the app models gets its
// row here; the running message is not one of them — `chat_view.dart` routes
// that to `StreamingTailView` instead, which is why nothing in this file touches
// the streaming tail.

import 'package:flutter/material.dart';

import '../../model/conversation.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../../l10n/app_localizations.dart';
import '../../state/backup_service.dart' show writeMessageExport;
import '../primitives/menu.dart';
import '../primitives/state_dot.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_lucide/flutter_lucide.dart';
import '../tool/tool_card.dart';
import 'assistant_body.dart';

class MessageItem extends StatelessWidget {
  const MessageItem({super.key, required this.node});

  final ConversationNode node;

  @override
  Widget build(BuildContext context) => switch (node) {
    UserMessageNode(:final text) => _messageMenu(
      context,
      _UserBubble(text: text),
      text,
    ),
    AssistantMessageNode(:final text, :final reasoning) => _messageMenu(
      context,
      AssistantBody(reasoning: reasoning, text: text),
      text,
    ),
    ToolCallNode() => ToolCard(node: node as ToolCallNode),
    ErrorNode(:final message) => _TurnError(message: message),
  };

  /// The message-level verbs (ADR-0066): copy the text in place, or take it
  /// away as a file. Markdown export writes the message as-is — converting
  /// markdown to "plain text" is an ill-defined transform, and doing it
  /// badly would be a lie about what was said.
  Widget _messageMenu(BuildContext context, Widget child, String text) =>
      DswContextMenu(
        items: (menuContext) => [
          DswMenuEntry(
            icon: LucideIcons.copy,
            label: AppLocalizations.of(menuContext).messageCopyText,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: text));
            },
          ),
          DswMenuEntry(
            icon: LucideIcons.file_output,
            label: AppLocalizations.of(menuContext).messageExportMd,
            onTap: () => _exportMessage(menuContext, text, 'md'),
          ),
          DswMenuEntry(
            icon: LucideIcons.download,
            label: AppLocalizations.of(menuContext).messageExportTxt,
            onTap: () => _exportMessage(menuContext, text, 'txt'),
          ),
        ],
        child: child,
      );

  Future<void> _exportMessage(
    BuildContext context,
    String text,
    String extension,
  ) async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: AppLocalizations.of(context).messageExportMd,
      fileName: _exportFileName(extension),
      type: FileType.custom,
      allowedExtensions: [extension],
    );
    if (path == null) return;
    await writeMessageExport(path, text);
  }
}

/// `planstar_message_YYYYMMDD_HHMMSS.<ext>` — the backup's stamp format.
String _exportFileName(String extension) {
  final now = DateTime.now();
  final stamp =
      '${now.year}'
      '${now.month.toString().padLeft(2, '0')}'
      '${now.day.toString().padLeft(2, '0')}_'
      '${now.hour.toString().padLeft(2, '0')}'
      '${now.minute.toString().padLeft(2, '0')}'
      '${now.second.toString().padLeft(2, '0')}';
  return 'planstar_message_$stamp.$extension';
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
                // Not `pill`: Flutter clamps a radius to half the box, so the
                // shorter the message the rounder a pill gets until `h'i` reads
                // as an avatar. The ramp reserves `pill` for dots and avatars
                // (`dsw_shape.dart:27`). The near-square top-right points at the
                // edge the message came from, and the hairline says "surface"
                // the way every other floating layer here does.
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(DswShape.shell),
                  topRight: const Radius.circular(DswShape.inset),
                  bottomRight: const Radius.circular(DswShape.shell),
                  bottomLeft: const Radius.circular(DswShape.shell),
                ),
                border: Border.all(color: color.borderL2),
              ),
              child: Padding(
                // 10 + 24 + 10: the 44px single-line bubble the source calls out.
                // The border is painted inside that box, so the seat did not
                // grow with it.
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
        TextSpan(
          text: message,
          style: body.copyWith(color: color.labelSecondary),
        ),
      ],
    ),
  );
}
