// The composer-takeover approval prompt.
//
// A port of `ApprovalPanel.module.css` / `ApprovalPanel.tsx` (designer draft
// approval.png). While a tool is waiting on an answer this replaces the input
// card rather than stacking above it — there is nothing useful to type — and it
// keeps the card's floating-capsule footprint so the swap is a content change
// rather than a layout jump.
//
// The justification and the target are unbounded, so they scroll inside the card
// at the shared composer cap while the strip and the action row stay outside it:
// the buttons must be reachable no matter how long the text is, or the approval
// cannot be answered at all.

import 'package:flutter/material.dart';

import '../../model/conversation.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';
import 'conversation_root.dart';

class ApprovalPanel extends StatefulWidget {
  const ApprovalPanel({
    super.key,
    required this.request,
    required this.onRespond,
  });

  final ApprovalRequest request;

  /// The verdict. The runtime resumes the interrupted call with it, which is why
  /// the panel does not need to know anything about the tool.
  final void Function(bool approved) onRespond;

  @override
  State<ApprovalPanel> createState() => _ApprovalPanelState();
}

class _ApprovalPanelState extends State<ApprovalPanel> {
  /// One-shot latch: the panel stays until the controller clears the request, so
  /// until then the buttons must not re-fire.
  bool _answered = false;

  @override
  void didUpdateWidget(ApprovalPanel old) {
    super.didUpdateWidget(old);
    // A second approval in the same turn reuses this seat, so the latch has to
    // re-arm on identity rather than on mount.
    if (old.request.ref != widget.request.ref) _answered = false;
  }

  void _answer(bool approved) {
    setState(() => _answered = true);
    widget.onRespond(approved);
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      // Sides = clearance + 16, so the card lands on the shared content width —
      // 32px narrower than the input card it replaces, at every viewport.
      padding: const EdgeInsets.fromLTRB(
        composerSideClearance + 16,
        8,
        composerSideClearance + 16,
        12,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: chatContentWidth),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: color.inputMajor,
              // Warn semantics ride the state tokens; the stroke is what marks
              // this card out from the input card it stands in for.
              border: Border.all(color: color.stateWarnSecondary),
              borderRadius: BorderRadius.circular(20),
              boxShadow: DswShadow.lv2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [_strip(color), _body(color), _actions(color)],
            ),
          ),
        ),
      ),
    );
  }

  /// The tinted full-width header band.
  Widget _strip(DswAlias color) => Container(
    color: color.stateWarnTertiary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.stateWarnPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Waiting for approval',
          style: DswType.xs13.copyWith(
            // 13/18 here, not the token's 13/20: the strip is a band, not prose.
            height: 18 / 13,
            color: color.stateWarnPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _body(DswAlias color) {
    final target = _target();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: composerTextMaxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The headline is the panel's message, not a footnote.
            Text(
              'Tool ${widget.request.toolName} requests privileged execution',
              style: DswType.s14.copyWith(
                fontSize: 15,
                height: 24 / 15,
                fontWeight: FontWeight.w500,
                color: color.labelPrimary,
              ),
            ),
            if (target != null) ...[
              const SizedBox(height: 6),
              SelectableText(
                target,
                style: DswType.xs13.copyWith(
                  fontFamily: dswFontFamilyCode,
                  fontFamilyFallback: dswFontFamilyCodeFallback,
                  color: color.labelTertiary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The muted code line: what the call would actually touch.
  ///
  /// dsh reads `command` off its shell tools' arguments and the path off its file
  /// tools'; the interrupt payload carries a `kind` saying which of those this is,
  /// so the line reads as the answer to the question the user is being asked —
  /// the command for `bash`, and for the two file tools the path plus the facts
  /// that decide the verdict: how much is being written, and whether anything is
  /// being overwritten.
  String? _target() {
    final details = widget.request.details;
    if (details['kind'] == 'bash') {
      final command = details['command'] ?? widget.request.arguments['command'];
      if (command is! String || command.isEmpty) return null;
      final workdir = details['workdir'];
      // The directory only when it is not the root: `in .` is noise on almost
      // every command, and the root is where a command runs unless it says
      // otherwise.
      return workdir is String && workdir.isNotEmpty && workdir != '.'
          ? '$command  ·  in $workdir'
          : command;
    }

    final path = details['path'] ?? widget.request.arguments['file_path'];
    if (path is! String || path.isEmpty) return null;
    final parts = [path];
    final replacements = details['replacements'];
    if (replacements is num) {
      parts.add(replacements == 1 ? '1 replacement' : '$replacements replacements');
    }
    final bytes = details['bytes'];
    if (bytes is num && replacements == null) parts.add('$bytes B');
    if (details['exists'] == true) parts.add('overwrites an existing file');
    return parts.join(' · ');
  }

  /// A card-level row, outside the scroll region: 14px above and below, which
  /// reproduces the metrics the row had when it was body content.
  Widget _actions(DswAlias color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CapsuleButton(
          label: 'Reject',
          enabled: !_answered,
          danger: true,
          onTap: () => _answer(false),
        ),
        const SizedBox(width: 8),
        CapsuleButton(
          label: 'Allow once',
          enabled: !_answered,
          variant: CapsuleVariant.primary,
          onTap: () => _answer(true),
        ),
      ],
    ),
  );
}
