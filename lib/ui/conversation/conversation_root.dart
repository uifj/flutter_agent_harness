// The center column: transcript above, composer seat below.
//
// A port of `ConversationRoot.module.css`. It owns the shared width axis for the
// whole column — one content width for the transcript, that width plus 32px for
// the input card — and the two phases: the hero, where an empty session centres
// its composer, and the active phase, where the composer docks to the bottom and
// the transcript scrolls beneath it.
//
// dsh docks the seat with `position: sticky` and fades the transcript out under
// it. Flutter has no sticky, so the seat is a stack sibling and the transcript
// pays for it in bottom padding, measured from the seat one frame late — which is
// what dsh's own `--dsh-composer-height` resize observer does.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../l10n/locales.dart';
import '../../model/approval_mode.dart';
import '../../model/conversation.dart';
import '../../model/workspace_index.dart';
import '../../state/conversation_controller.dart';
import '../../state/model_directory.dart';
import '../../state/streaming_tail.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'approval_panel.dart';
import 'chat_view.dart';
import 'composer.dart';
import 'hero_workspace_picker.dart';
import 'plan_review_panel.dart';

/// dsh's `formatDuration`: 45.2s under a minute, 2m42s from there on. Shared
/// by the stats row's every duration figure, so the whole line speaks one
/// unit system.
String formatStatsDuration(int ms) {
  final seconds = ms / 1000;
  if (seconds < 60) return '${(seconds * 10).round() / 10}s';
  final whole = seconds.round();
  return '${whole ~/ 60}m${whole % 60}s';
}

/// `--dsh-chat-content-width`. The transcript column, and the axis every other
/// card in this column is measured against.
const chatContentWidth = 748.0;

/// `--dsh-composer-card-max-width`: the content width plus both 16px insets. The
/// input card is the one element allowed to be wider than the transcript.
const composerCardMaxWidth = chatContentWidth + 32;

/// `--dsh-composer-side-clearance`. The transcript pads this plus 16px per side,
/// so it stays exactly 32px narrower than the input card at every viewport.
const composerSideClearance = 16.0;

/// `--dsh-composer-stack-gap`: the rhythm between stacked composer cards.
const composerStackGap = 6.0;

/// `--dsh-composer-text-max-height`. The cap on every unbounded text region that
/// takes the composer seat, so the draft and the approval prompt occupy the same
/// box and swapping one for the other is not a layout jump.
const composerTextMaxHeight = 336.0;

/// The fade band at the top of the seat, in pixels rather than a fraction: a
/// growing draft must widen the solid region, not stretch the fade.
const composerMaskHeight = 36.0;

class ConversationRoot extends StatefulWidget {
  const ConversationRoot({
    super.key,
    required this.conversation,
    required this.tail,
    this.modelDirectory,
    this.onModelSelected,
    this.onLookupFiles,
  });

  final ConversationController conversation;
  final StreamingTail tail;

  /// The composer's model seat — dsh's `conversation.input.model`. Absent
  /// leaves the row without the chip (tests).
  final ModelDirectory? modelDirectory;

  /// Commits a model the seat picked. Absent leaves the chip inert.
  final ValueChanged<String>? onModelSelected;

  /// Supplies the workspace file index for the `@` mention menu — the seam
  /// dsh-at-file's Remote occupied. Absent disables the menu.
  final Future<List<FileEntry>> Function()? onLookupFiles;

  @override
  State<ConversationRoot> createState() => _ConversationRootState();
}

class _ConversationRootState extends State<ConversationRoot> {
  /// The measured seat height, which the transcript reserves as bottom padding.
  final _seatHeight = ValueNotifier<double>(0);

  /// The plan text the review card was answered or dismissed for. The card does
  /// not come back for the same plan once it has had its answer — a new plan
  /// text is a new review, and the guard is on the text rather than a counter
  /// precisely because that is the identity a restore replays too.
  String? _settledPlan;

  @override
  void dispose() {
    _seatHeight.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.dsw.bgBase,
    child: ListenableBuilder(
      listenable: widget.conversation,
      builder: (context, _) =>
          widget.conversation.nodes.isEmpty ? _hero() : _active(),
    ),
  );

  /// Hero phase: the composer stack is flex-centred, floated a little above true
  /// centre by a 32px foot, and capped at the card width plus both clearances so
  /// it lands at exactly the docked card's width.
  ///
  /// Above the composer sits the workspace picker — dsh's
  /// `conversation.hero.workspace` seat. A fresh install has no folder, and the
  /// hero is the first screen the user meets: the picker is the one control
  /// that explains what the app needs before any tool will run.
  Widget _hero() => Center(
    child: SizedBox(
      width: composerCardMaxWidth + 2 * composerSideClearance,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _headline(),
            const SizedBox(height: 8),
            const HeroWorkspacePicker(),
            const SizedBox(height: 8),
            _stack(hero: true),
          ],
        ),
      ),
    ),
  );

  /// `HeroShell.module.css:29-44`: a 34px mark, 10px gap, 26px/32px/500 text.
  ///
  /// The row scales down rather than overflowing when the centre column is at
  /// its floor — the hero is the one headline with no smaller step to fall
  /// back to, and a shrunken wordmark beats a clipped one.
  Widget _headline() {
    final color = context.dsw;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.droplet, size: 34, color: color.labelPrimary),
          const SizedBox(width: 10),
          Text(
            context.tr('askAnything'),
            style: DswType.xl24.copyWith(
              fontSize: 26,
              height: 32 / 26,
              fontWeight: FontWeight.w500,
              color: color.labelPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _active() => Stack(
    children: [
      Positioned.fill(
        child: ChatView(
          conversation: widget.conversation,
          tail: widget.tail,
          bottomInset: _seatHeight,
        ),
      ),
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: _Measured(
          onHeight: (height) => _seatHeight.value = height,
          child: _stack(hero: false),
        ),
      ),
    ],
  );

  /// dsh's StatsLine: the session's counts and durations, 12/20 tertiary,
  /// centered on the content axis, riding ABOVE the composer card so it
  /// sticks with it in the scrollport (`conversation.composer.dock`). The
  /// seat persists — empty while there is nothing to say — so the card does
  /// not shift when the first figures land.
  Widget _statsLine() {
    final color = context.dsw;
    final conversation = widget.conversation;
    final groups = <String>[];

    if (conversation.nodes.any((node) => node is UserMessageNode)) {
      final turns = conversation.nodes.whereType<UserMessageNode>().length;
      final steps =
          conversation.nodes.whereType<AssistantMessageNode>().length;
      groups.add(context.tr('statsCounts')
          .replaceAll('{turns}', '$turns')
          .replaceAll('{steps}', '$steps'));

      final durations = <String>[];
      if (conversation.llmWallMs > 0) {
        durations.add(context.tr('statsLlm')
            .replaceAll('{duration}', formatStatsDuration(conversation
                .llmWallMs)));
      }
      if (conversation.toolWallMs > 0) {
        durations.add(context.tr('statsTool')
            .replaceAll('{duration}', formatStatsDuration(conversation
                .toolWallMs)));
      }
      if (durations.isNotEmpty) groups.add(durations.join(' · '));

      final ttft = conversation.ttftAverageMs;
      if (ttft != null && ttft > 0) {
        groups.add(context.tr('statsTtft')
            .replaceAll('{duration}', formatStatsDuration(ttft.round())));
      }
    }

    if (groups.isEmpty) return const SizedBox(height: 4);
    // `.root`: block, centered, `padding: 4px (clearance + 16) 0` — the row
    // elides with ellipsis and its side pads match the transcript's, so the
    // figures sit on the same axis as the messages above them.
    return Padding(
      padding: EdgeInsets.only(
        bottom: 4,
        left: composerSideClearance + 16,
        right: composerSideClearance + 16,
      ),
      child: Text.rich(
        TextSpan(
          children: [
            for (var i = 0; i < groups.length; i++) ...[
              if (i > 0) ...[
                // `.sep`: the pipe in the separator colour with 10px on
                // either side — the spacing is the gap the flex row retired,
                // carried by the glyph itself.
                TextSpan(
                  text: ' | ',
                  style: DswType.xxs12.copyWith(
                    color: color.borderL1,
                  ),
                ),
              ],
              TextSpan(
                text: groups[i],
                style: DswType.xxs12.copyWith(color: color.labelTertiary),
              ),
            ],
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
      ),
    );
  }

  /// The composer stack. A pending approval takes the card's place rather than
  /// stacking above it: while the agent is waiting on an answer there is nothing
  /// useful to type. A plan awaiting review takes it next — plan mode is over
  /// precisely when the plan has been answered.
  Widget _stack({required bool hero}) {
    final approval = widget.conversation.pendingApproval;
    final card = switch (approval) {
      null => _planReview() ??
          Composer(
            hero: hero,
            busy: widget.conversation.isBusy,
            blocked: widget.conversation.isInputBlocked,
            approvalMode: widget.conversation.approvalMode,
            onApprovalMode: (mode) => widget.conversation.approvalMode = mode,
            onNewSession: widget.conversation.startNewSession,
            modelDirectory: widget.modelDirectory,
            onModelSelected: widget.onModelSelected,
            onLookupFiles: widget.onLookupFiles,
            onSubmit: (text, images) =>
                widget.conversation.send(text, images: images),
            onStop: widget.conversation.stop,
          ),
      _ => ApprovalPanel(
          request: approval,
          onRespond: widget.conversation.respondToApproval,
        ),
    };

    final content = Column(mainAxisSize: MainAxisSize.min, children: [
      // The stats row rides above whatever card is up — it describes the
      // session, not the input, so an approval or review card does not
      // displace it. HERO phase renders nothing: dsh's dock belongs to an
      // active session, and an empty conversation has no figures anyway.
      if (!hero) _statsLine(),
      card,
    ]);
    return hero ? content : _Masked(child: content);
  }

  /// The plan review card, when there is one to show.
  ///
  /// The trigger is the app's own plan-mode contract: while the mode is `plan`
  /// the workspace is read-only, and the plan of record is the thing the user
  /// is being asked to approve. The card goes away the moment any part of that
  /// stops holding — a busy turn, a mode change, or an answer already given for
  /// this exact plan text.
  Widget? _planReview() {
    final conversation = widget.conversation;
    if (conversation.approvalMode != ApprovalMode.plan) return null;
    if (conversation.isInputBlocked) return null;
    final plan = conversation.currentPlan;
    if (plan == null || plan == _settledPlan) return null;

    return PlanReviewPanel(
      plan: plan,
      onDiscuss: () => setState(() => _settledPlan = plan),
      onDecline: () {
        // Settled before the send: the send makes the turn busy, but a decline
        // that arrives without a reply would otherwise bring the card back.
        setState(() => _settledPlan = plan);
        conversation.send(context.tr('planDeclinedMessage'));
      },
      onApprove: () {
        // Mode first: the plan-mode gate is the thing being approved, and the
        // message rides to the agent through the normal ask-mode path.
        conversation.approvalMode = ApprovalMode.ask;
        conversation.send(context.tr('planApprovedMessage'));
      },
    );
  }
}

/// Paints the seat's backdrop: transparent at the top edge, the base background
/// from 36px down.
class _Masked extends StatelessWidget {
  const _Masked({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _MaskPainter(context.dsw.bgBase),
    child: child,
  );
}

class _MaskPainter extends CustomPainter {
  const _MaskPainter(this.base);

  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final rect = Offset.zero & size;
    // The band is a fixed pixel height converted to a stop here, at paint time,
    // because this is the only place the seat's height is known.
    final band = math.min(composerMaskHeight, size.height) / size.height;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base.withAlpha(0), base, base],
          stops: [0, band, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MaskPainter old) => old.base != base;
}

/// Reports its child's height after layout, once per change.
class _Measured extends StatefulWidget {
  const _Measured({required this.onHeight, required this.child});

  final ValueChanged<double> onHeight;
  final Widget child;

  @override
  State<_Measured> createState() => _MeasuredState();
}

class _MeasuredState extends State<_Measured> {
  double? _reported;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = context.size?.height;
      if (height == null || height == _reported) return;
      _reported = height;
      widget.onHeight(height);
    });
    return widget.child;
  }
}
