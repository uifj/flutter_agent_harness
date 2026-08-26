// The details column: the selected tool call's arguments and result.
//
// A port of `skeleton/DetailsPanel.tsx` and `DetailsPanel.module.css` — header
// (name + close) over a scrolling body of Input/Output sections, and the three
// things the body can say instead: nothing selected, the selected call is no
// longer in the window, the call is still running.
//
// It holds no state of its own, exactly as the source says: the selection comes
// from `DetailsSelection` and the material is looked up in the transcript. In dsh
// the lookup walks the session snapshot; here the transcript IS the projection,
// so a call that is not in it is the `notInWindow` case — which is what a session
// switch or a new session leaves behind.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../model/conversation.dart';
import '../../state/conversation_controller.dart';
import '../../state/details_selection.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/code_block.dart';

/// `ui-conversation/src/client/locales.ts:255-261`, the `en` entries. This build
/// has no dictionary — every other string in it is written where it is used — so
/// the dictionary's own English is what lands here.
const _title = 'Details';
const _close = 'Close details';
const _empty = 'Click a tool row in the message flow to view its details';
const _notInWindow = 'This call is outside the current window';
const _input = 'Input';
const _output = 'Output';
const _running = 'Running…';

class DetailsPanel extends StatefulWidget {
  const DetailsPanel({
    super.key,
    required this.conversation,
    required this.selection,
    required this.onClose,
  });

  /// Where the material comes from. The panel reads it and never writes it.
  final ConversationController conversation;

  final DetailsSelection selection;

  /// dsh's `closeDetails`, which closes the column. Whether the selection is
  /// dropped with it is the caller's call — see `main.dart`.
  final VoidCallback onClose;

  @override
  State<DetailsPanel> createState() => _DetailsPanelState();
}

class _DetailsPanelState extends State<DetailsPanel> {
  /// Both sources move the panel: a new selection, and a status change on the
  /// call already selected (running → settled is what swaps `Running…` for the
  /// result). Merged once here rather than per build, so a rebuild does not
  /// re-subscribe to either.
  late Listenable _sources;

  @override
  void initState() {
    super.initState();
    _sources = Listenable.merge([widget.conversation, widget.selection]);
  }

  @override
  void didUpdateWidget(DetailsPanel old) {
    super.didUpdateWidget(old);
    if (old.conversation == widget.conversation &&
        old.selection == widget.selection) {
      return;
    }
    _sources = Listenable.merge([widget.conversation, widget.selection]);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    // `border-left: 1px solid border-l2` is not set here: the frame draws the
    // seam between the center and this column, because only the frame knows
    // whether the column is open — a closed one must not paint one.
    return ColoredBox(
      color: color.bgBase,
      child: ListenableBuilder(
        listenable: _sources,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [_header(color), Expanded(child: _body(color))],
        ),
      ),
    );
  }

  /// `.header`: pad 14/12/12, gap 8, space-between, hairline under.
  Widget _header(DswAlias color) => Container(
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: color.borderL2)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            // dsh prefers the snapshot's own tool name and keeps
            // `selection.toolName` as the fallback, because its selection can be
            // written by code that does not know the name. Here only the tool row
            // writes it, and the row knows its own display title, so the
            // selection is the single source and the two can never disagree.
            widget.selection.toolName ?? _title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DswType.s14.copyWith(
              height: 20 / 14,
              fontWeight: FontWeight.w500,
              color: color.labelPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CloseButton(onTap: widget.onClose),
      ],
    ),
  );

  /// `.body`: pad 12/16, scrolls.
  Widget _body(DswAlias color) {
    final callId = widget.selection.callId;
    if (callId == null) return _padded(_message(color, _empty));

    final node = _find(callId);
    if (node == null) return _padded(_message(color, _notInWindow));

    return _padded(
      // dsh keys only the Output fragment, naming the reason: the body owns
      // per-call view state that React would otherwise carry into the next
      // selection. The Input `CodeBlock` owns exactly that kind of state here
      // (its copy confirmation), so the key goes around both.
      KeyedSubtree(
        key: ValueKey(callId),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // `argsRaw !== null`: a call always has an args blob, so this section
            // is always here — an empty one shows `{}`, as it does in dsh.
            _sectionLabel(color, _input),
            // 16, not the label's own 6: dsh's `CodeBlock` carries `margin: 16px
            // 0`, which collapses with the label's margin to the larger of the
            // two. The bare `<pre>` under Output carries none, which is why that
            // gap is 6. The asymmetry is the source's.
            const SizedBox(height: 16),
            CodeBlock(code: _pretty(node.arguments), lang: 'json'),
            const SizedBox(height: 16),
            _sectionLabel(color, _output),
            const SizedBox(height: 6),
            _outputBody(color, node),
            // `.section { margin-bottom: 16px }` on the last section too: it
            // does not collapse out through the body's padding.
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _padded(Widget child) => SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: child,
  );

  /// The settled/running split, read off the status rather than kept as a flag —
  /// dsh's `'kind' in block` discrimination. Both pauses count as unsettled: a
  /// call waiting on approval has not produced anything yet.
  Widget _outputBody(DswAlias color, ToolCallNode node) {
    final settled =
        node.status != ToolStatus.running &&
        node.status != ToolStatus.awaitingApproval;
    if (!settled) return _message(color, _running);
    return _Pre(
      text: node.errorMessage ?? _format(node.output) ?? '',
      isError: node.errorMessage != null,
    );
  }

  /// `.empty`: pad 8/0, 13/20 tertiary. The three body states share it.
  Widget _message(DswAlias color, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: DswType.xs13.copyWith(height: 20 / 13, color: color.labelTertiary),
    ),
  );

  /// `.sectionLabel`: 12/18 wt500 secondary.
  Widget _sectionLabel(DswAlias color, String text) => Text(
    text,
    style: DswType.xs13.copyWith(
      fontSize: 12,
      height: 18 / 12,
      fontWeight: FontWeight.w500,
      color: color.labelSecondary,
    ),
  );

  ToolCallNode? _find(String callId) {
    for (final node in widget.conversation.nodes) {
      if (node is ToolCallNode && node.id == callId) return node;
    }
    return null;
  }
}

/// `.close`: a 28px circle, hover-filled, holding the 14px cross the source draws
/// as a two-stroke path.
class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: _close,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _hovered ? color.interactiveBgHover : null,
            ),
            child: Center(
              child: Icon(LucideIcons.x, size: 14, color: color.labelSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.code`: the no-card fallback for a result — r12, pad 16, mono 13/22, wrapped,
/// red when the call failed.
///
/// This is dsh's fallback path, not its card path. Its `conversation.details.tool`
/// slot swaps in a terminal / diff / read card for the tools that have one; none
/// of the three tools here does, so there is nothing yet for a card to render.
class _Pre extends StatelessWidget {
  const _Pre({required this.text, required this.isError});

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.markdownCodeBlock,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        text,
        style: DswType.markdownCodeBlock.copyWith(
          color: isError ? color.stateErrorPrimary : color.labelPrimary,
        ),
      ),
    );
  }
}

/// dsh reparses and reprints `argsRaw` here rather than reusing the row's copy,
/// and keeps a `rawResultText` of its own beside it. The same two live here, for
/// the same reason: the panel is a different presentation of the same call, and
/// tying it to the row's private formatting would couple them for nothing.
String _pretty(Object value) {
  try {
    return const JsonEncoder.withIndent('  ').convert(value);
  } on JsonUnsupportedObjectError {
    return value.toString();
  }
}

String? _format(Object? output) {
  if (output == null) return null;
  if (output is String) return output;
  return _pretty(output);
}
