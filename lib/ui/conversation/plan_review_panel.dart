// The composer takeover for a plan awaiting review.
//
// A port of `PlanReviewPanel.tsx`: a plan under review is one decision over one
// body of markdown, so it takes the waiting-approval card shape — tinted strip,
// scrolling content, right-aligned action row — rather than a question pager.
//
// The three actions are the whole decision surface: approve flips the app to
// ask mode (the plan-mode gate exists precisely until this click) and tells the
// agent to proceed; decline keeps plan mode and tells the agent to revise;
// discuss just dismisses the card so the composer returns and the user can say
// what they want. Dismissal is a real answer, not an escape hatch.

import 'package:flutter/material.dart';

import '../../l10n/locales.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/capsule_button.dart';
import 'assistant_markdown.dart';
import 'conversation_root.dart';

class PlanReviewPanel extends StatefulWidget {
  const PlanReviewPanel({
    super.key,
    required this.plan,
    required this.onApprove,
    required this.onDecline,
    required this.onDiscuss,
  });

  /// The plan of record, as markdown.
  final String plan;

  /// Approve: leave plan mode and let the agent execute.
  final VoidCallback onApprove;

  /// Decline: stay read-only and send the agent back to revise.
  final VoidCallback onDecline;

  /// Dismiss the card and return the composer, so the user can type feedback.
  final VoidCallback onDiscuss;

  @override
  State<PlanReviewPanel> createState() => _PlanReviewPanelState();
}

class _PlanReviewPanelState extends State<PlanReviewPanel> {
  /// One-shot latch shaped like the approval takeover's: the card leaves only
  /// when the host state moves, so until then a second click must not re-fire.
  bool _acted = false;

  @override
  void didUpdateWidget(PlanReviewPanel old) {
    super.didUpdateWidget(old);
    // A new plan text is a new review; the latch re-arms with it.
    if (old.plan != widget.plan) _acted = false;
  }

  void _act(VoidCallback action) {
    if (_acted) return;
    setState(() => _acted = true);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      // Sides = clearance + 16, so the card lands on the shared content width —
      // the same footprint the approval card and the input card swap between.
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
              border: Border.all(color: color.stateBusinessPrimary),
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

  /// The tinted full-width header band. Business rather than warn: this is a
  /// plan, not a hazard — the colour says "the agent is waiting on a decision",
  /// not "something is about to change".
  Widget _strip(DswAlias color) => Container(
    color: color.stateBusinessTertiary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color.stateBusinessPrimary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.tr('planReviewHeader'),
          style: DswType.xs13.copyWith(
            height: 18 / 13,
            color: color.stateBusinessPrimary,
          ),
        ),
      ],
    ),
  );

  /// The plan body, scrolled inside the shared composer text cap so the strip
  /// and the action row stay reachable no matter how long the plan is.
  Widget _body(DswAlias color) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: composerTextMaxHeight),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: AssistantMarkdown(widget.plan),
    ),
  );

  /// Right-aligned, weakest to strongest: discuss, decline, approve.
  Widget _actions(DswAlias color) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        CapsuleButton(
          label: context.tr('planDiscuss'),
          enabled: !_acted,
          onTap: () => _act(widget.onDiscuss),
        ),
        const SizedBox(width: 8),
        CapsuleButton(
          label: context.tr('planDecline'),
          enabled: !_acted,
          danger: true,
          onTap: () => _act(widget.onDecline),
        ),
        const SizedBox(width: 8),
        CapsuleButton(
          label: context.tr('planApprove'),
          enabled: !_acted,
          variant: CapsuleVariant.primary,
          onTap: () => _act(widget.onApprove),
        ),
      ],
    ),
  );
}
