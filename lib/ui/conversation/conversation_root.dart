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

import '../../state/conversation_controller.dart';
import '../../state/streaming_tail.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'approval_panel.dart';
import 'chat_view.dart';
import 'composer.dart';

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
  });

  final ConversationController conversation;
  final StreamingTail tail;

  @override
  State<ConversationRoot> createState() => _ConversationRootState();
}

class _ConversationRootState extends State<ConversationRoot> {
  /// The measured seat height, which the transcript reserves as bottom padding.
  final _seatHeight = ValueNotifier<double>(0);

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
  Widget _hero() => Center(
    child: SizedBox(
      width: composerCardMaxWidth + 2 * composerSideClearance,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_headline(), const SizedBox(height: 8), _stack(hero: true)],
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
            'Ask anything',
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

  /// The composer stack. A pending approval takes the card's place rather than
  /// stacking above it: while the agent is waiting on an answer there is nothing
  /// useful to type.
  Widget _stack({required bool hero}) {
    final approval = widget.conversation.pendingApproval;
    final card = approval == null
        ? Composer(
            hero: hero,
            busy: widget.conversation.isBusy,
            blocked: widget.conversation.isInputBlocked,
            onSubmit: widget.conversation.send,
            onStop: widget.conversation.stop,
          )
        : ApprovalPanel(
            request: approval,
            onRespond: widget.conversation.respondToApproval,
          );

    final content = Column(mainAxisSize: MainAxisSize.min, children: [card]);
    return hero ? content : _Masked(child: content);
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
