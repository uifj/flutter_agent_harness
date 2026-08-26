// The transcript.
//
// A port of `ChatView.module.css`: a full-bleed scroller with 16px of vertical
// padding and sides of `clearance + 16`, holding a 748px column centred on the
// same axis as the input card, with one 16px rhythm between rows.
//
// dsh leaves virtualisation as a future note on its `.flowItem` seam;
// `ListView.builder` already builds on demand, so this port is ahead of the
// original there and no extra machinery is warranted.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter/scheduler.dart';

import '../../model/conversation.dart';
import '../../state/conversation_controller.dart';
import '../../state/streaming_tail.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_static.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import 'conversation_root.dart';
import 'message_item.dart';
import 'streaming_tail_view.dart';

/// `FOLLOW_THRESHOLD`: how close to the floor still counts as being at the
/// bottom, so a stray pixel of overscroll does not unpin the reader.
const _followThreshold = 24.0;

/// `use-throttled-visual-update`'s default interval. Scroll following is visual
/// alignment, not content, so it is allowed to lag by a few frames — the content
/// itself is never throttled.
const _followIntervalFrames = 3;

class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.conversation,
    required this.tail,
    required this.bottomInset,
  });

  final ConversationController conversation;
  final StreamingTail tail;

  /// The composer seat's measured height. The transcript reserves it as bottom
  /// padding so the last row can still be scrolled clear of the card.
  final ValueListenable<double> bottomInset;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _scroll = ScrollController();

  /// Whether the transcript is following the tip. Set by the reader's own
  /// scrolling, and reasserted whenever they send something.
  bool _pinned = true;
  bool _atBottom = true;

  String? _lastNodeId;
  bool _followScheduled = false;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatView old) {
    super.didUpdateWidget(old);
    if (old.conversation == widget.conversation && old.tail == widget.tail) {
      return;
    }
    _unsubscribe(old.conversation, old.tail);
    _subscribe();
  }

  @override
  void dispose() {
    _unsubscribe(widget.conversation, widget.tail);
    _scroll.dispose();
    super.dispose();
  }

  void _subscribe() {
    widget.conversation.addListener(_onContentChanged);
    widget.tail.text.addListener(_onContentChanged);
    widget.tail.reasoning.addListener(_onContentChanged);
  }

  void _unsubscribe(ConversationController conversation, StreamingTail tail) {
    conversation.removeListener(_onContentChanged);
    tail.text.removeListener(_onContentChanged);
    tail.reasoning.removeListener(_onContentChanged);
  }

  // ---------------------------------------------------------------------------
  // Following
  // ---------------------------------------------------------------------------

  void _onContentChanged() {
    final nodes = widget.conversation.nodes;
    final lastId = nodes.isEmpty ? null : nodes.last.id;
    if (lastId != _lastNodeId) {
      _lastNodeId = lastId;
      // The reader just spoke, so they are looking at the bottom whatever they
      // were reading before.
      if (nodes.isNotEmpty && nodes.last is UserMessageNode) _pinned = true;
    }
    if (_pinned) _scheduleFollow();
  }

  /// Coalesces follow requests over [_followIntervalFrames], leading-edge
  /// ignored: a burst of token deltas ends in one jump, and the jump happens
  /// after the frame that grew the list has been laid out.
  void _scheduleFollow() {
    if (_followScheduled) return;
    _followScheduled = true;
    var remaining = _followIntervalFrames;
    void advance(Duration _) {
      if (!mounted) {
        _followScheduled = false;
        return;
      }
      remaining -= 1;
      if (remaining > 0) {
        WidgetsBinding.instance.addPostFrameCallback(advance);
        return;
      }
      _followScheduled = false;
      _follow();
    }

    WidgetsBinding.instance.addPostFrameCallback(advance);
  }

  void _follow() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent) return;
    position.jumpTo(position.maxScrollExtent);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // `+ 1` mirrors the source's own slack on the comparison.
    final atBottom =
        position.maxScrollExtent - position.pixels <= _followThreshold + 1;
    // Ownership follows the reader: scrolling away stops the follow, coming back
    // resumes it. Programmatic jumps land on the floor, so they preserve it.
    _pinned = atBottom;
    if (atBottom == _atBottom) return;
    setState(() => _atBottom = atBottom);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: widget.bottomInset,
    builder: (context, inset, _) => LayoutBuilder(
      builder: (context, constraints) {
        // Sides = composer clearance + 16, which keeps the transcript exactly
        // 32px narrower than the input card at every viewport.
        const side = composerSideClearance + 16;
        final available = constraints.maxWidth - 2 * side;
        final column = available < chatContentWidth
            ? available
            : chatContentWidth;
        return Stack(
          children: [
            Positioned.fill(child: _list(inset, side, column)),
            if (!_atBottom)
              Positioned(
                bottom: inset + 16,
                // The control tracks the column's right edge, not the window's.
                right: side + (available - column) / 2,
                child: _ToBottomButton(onTap: _backToBottom),
              ),
          ],
        );
      },
    ),
  );

  Widget _list(double inset, double side, double column) {
    final nodes = widget.conversation.nodes;
    // The activity label is a flow row of its own, so it inherits the column's
    // 16px rhythm instead of inventing spacing.
    final count = nodes.length + (widget.conversation.isBusy ? 1 : 0);
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(side, 16, side, 16 + inset),
      itemCount: count,
      itemBuilder: (context, index) {
        final child = index < nodes.length
            ? _node(nodes[index])
            : const _TurnStatus();
        return Padding(
          padding: EdgeInsets.only(bottom: index == count - 1 ? 0 : 16),
          child: Center(child: SizedBox(width: column, child: child)),
        );
      },
    );
  }

  /// The running message defers to the tail's own notifiers; everything else is
  /// a settled row.
  Widget _node(ConversationNode node) {
    if (node is AssistantMessageNode && node.isStreaming) {
      return StreamingTailView(key: ValueKey(node.id), tail: widget.tail);
    }
    return MessageItem(key: ValueKey(node.id), node: node);
  }

  void _backToBottom() {
    _pinned = true;
    _follow();
    if (!_atBottom) setState(() => _atBottom = true);
  }
}

/// `ChatView.module.css:72-120`: the turn's activity label, kept to the one-line
/// footprint of the loader it replaced. A pale brand band sweeps across the
/// glyphs themselves — `background-clip: text`, which is a shader mask here.
class _TurnStatus extends StatefulWidget {
  const _TurnStatus();

  @override
  State<_TurnStatus> createState() => _TurnStatusState();
}

// Two tickers, so the plural mixin: the sweep and the clock run at different
// periods and the clock has to keep counting while the sweep is stopped for
// reduced motion.
class _TurnStatusState extends State<_TurnStatus>
    with TickerProviderStateMixin {
  /// Anchored at mount. dsh anchors to the turn's logged start and falls back to
  /// mount time; this build has no turn log, so the fallback is the only path.
  final _startedAt = DateTime.now();
  late final AnimationController _shimmer;
  late final Ticker _clock;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Both built here rather than lazily at first use: a ticker created during
    // build is a side effect in build, and it made the ordering between these two
    // load-bearing.
    _shimmer = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );
    _clock = createTicker(_onClockTick)..start();
  }

  void _onClockTick(Duration _) {
    final elapsed = DateTime.now().difference(_startedAt);
    // The label only shows whole seconds, so anything finer is a wasted frame.
    if (elapsed.inSeconds == _elapsed.inSeconds) return;
    setState(() => _elapsed = elapsed);
  }

  @override
  void dispose() {
    _clock.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final still = MediaQuery.disableAnimationsOf(context);
    if (still) {
      _shimmer.stop();
    } else if (!_shimmer.isAnimating) {
      _shimmer.repeat();
    }

    // The clock only appears once the turn has clearly been running for a while.
    final showClock = _elapsed.inMilliseconds >= 15000;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: 26,
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _shimmer,
              builder: (context, _) => ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) => _shader(bounds, still),
                child: Text('Deep diving...', style: DswType.sStrong14),
              ),
            ),
            if (showClock)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  _duration(_elapsed),
                  // Restored to a flat caption colour: the band is for the label
                  // only, and the source re-fills this span for that reason.
                  style: DswType.xs13.copyWith(
                    color: color.labelCaption,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The band: a 250%-wide gradient travelling from its right edge to its left,
  /// so the pale 200 step crosses the text once per cycle. Reduced motion keeps
  /// the source's static frame — one pass, parked.
  Shader _shader(Rect bounds, bool still) {
    const gradient = LinearGradient(
      colors: [
        DswStatic.deepseek500,
        DswStatic.deepseek500,
        DswStatic.deepseek200,
        DswStatic.deepseek500,
        DswStatic.deepseek500,
      ],
      stops: [0, 0.4, 0.5, 0.6, 1],
    );
    if (still) return gradient.createShader(bounds);
    final width = bounds.width * 2.5;
    // `background-position` runs 100% -> 0%: at 100% the band's right edge meets
    // the text's right edge, at 0% both left edges meet.
    final progress = 1 - _shimmer.value;
    final left = bounds.left + (bounds.width - width) * progress;
    return gradient.createShader(
      Rect.fromLTWH(left, bounds.top, width, bounds.height),
    );
  }

  /// `formatRunDuration`: seconds alone under a minute, `m s` above it.
  static String _duration(Duration elapsed) {
    final total = elapsed.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    if (minutes == 0) return '${seconds}s';
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }
}

/// `ChatView.module.css:178-197`: a floating 34px control that appears only once
/// the reader has scrolled away from the tip.
class _ToBottomButton extends StatefulWidget {
  const _ToBottomButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ToBottomButton> createState() => _ToBottomButtonState();
}

class _ToBottomButtonState extends State<_ToBottomButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: 'Back to bottom',
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: _circle(color),
        ),
      ),
    );
  }

  Widget _circle(DswAlias color) => Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: _hovered ? color.buttonFloatingHover : color.buttonFloatingFill,
      border: Border.all(color: color.borderL2),
      borderRadius: BorderRadius.circular(100),
      boxShadow: DswShadow.lv2,
    ),
    child: Icon(LucideIcons.arrow_down, size: 16, color: color.labelPrimary),
  );
}
