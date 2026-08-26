// The sub-agent tab.
//
// A port of `DSH-better-sidebar/src/client/SubagentView.tsx` over this app's
// transcript instead of the source's session catalog. The topology there is
// assembled from durable child-session descriptors the host pushes; here a
// delegation is a `delegate_to_*` tool call the [ConversationController] already
// projects, so the tree is derived from it and there is no second store. What
// the source does that this does not, and why:
//
//   * Multi-level topology. The source's sub-agents spawn sub-agents; this
//     delegation target has no delegation tools (read-only — see
//     `agent_runtime.dart`), so the tree is exactly two levels and the source's
//     recursive CatalogRows collapses to one block of child cards.
//   * Live "last text + tool call" lines. The source polls a live feed; the
//     middleware runs a delegation to completion before anything surfaces, so a
//     running card shows the source's own no-live-data fallback ("Thinking…")
//     and the result lands whole in the dock below.
//   * The Jobs section. The source lists background shell jobs beside the
//     topology; this runtime has none — bash blocks the turn — so the
//     delegation cards take over the jobs' affordances (the kind-chip command
//     line, the two-click kill, the shared output dock) rather than shipping
//     an empty section.
//   * The refresh button. The projection is synchronous off the transcript, so
//     there is nothing to re-fetch; wiring the button to a no-op would only
//     claim a capability.
//
// The whole page is honest about one more narrowing: a kill stops the *turn*
// (`ConversationController.stop`), because a delegation runs inside the parent
// turn's tool loop — there is no channel that ends one and preserves the
// other. The sub-agent's own loop is cut by the stop gate it shares with the
// parent (see `agent_runtime.dart`).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../model/conversation.dart';
import '../../../state/conversation_controller.dart';
import '../../../theme/dsw_theme.dart';
import '../../../theme/dsw_typography.dart';
import '../../../ui/primitives/state_dot.dart';
import '../../model/sidebar_tab.dart';
import '../../state/workbench_controller.dart';

// ---- The host --------------------------------------------------------------

/// The conversation seam, in reach of tab bodies.
///
/// Same reason as [GitHost] in git_tab.dart and TerminalHost in
/// terminal_tab.dart: bodies are built by the global registry, whose builders
/// cannot capture an app-scoped object without pinning whichever instance
/// registered first. The controller — not a turn source — is what rides on the
/// scope, because the projection reads the transcript, which survives runtime
/// rebuilds (`adoptRuntime` keeps this instance).
class SubagentHost extends InheritedWidget {
  const SubagentHost({
    super.key,
    required this.conversation,
    required super.child,
  });

  final ConversationController conversation;

  /// The controller below [context]. Throws rather than defaulting: a sub-agent
  /// tab outside a SubagentHost is a wiring bug, and a silent fallback
  /// controller would show a topology that is forever empty.
  static ConversationController of(BuildContext context) {
    final host = context.dependOnInheritedWidgetOfExactType<SubagentHost>();
    if (host == null) {
      throw StateError('SubagentTab needs a SubagentHost ancestor');
    }
    return host.conversation;
  }

  @override
  bool updateShouldNotify(SubagentHost oldWidget) =>
      conversation != oldWidget.conversation;
}

// ---- The view vocabulary, ported from SubagentView.tsx ----------------------

/// The prefix the agents middleware gives its delegation tools.
const delegatePrefix = 'delegate_to_';

/// Whether [node] is a delegation this tab tracks.
bool isDelegation(ToolCallNode node) => node.name.startsWith(delegatePrefix);

/// The agent behind a delegation tool name (`delegate_to_general-purpose` →
/// `general-purpose`), or the whole name when it carries no prefix.
String agentNameOf(String toolName) => toolName.startsWith(delegatePrefix)
    ? toolName.substring(delegatePrefix.length)
    : toolName;

/// The dot a delegation shows, by where its call has got to.
StateDotState dotStateOf(ToolStatus status) => switch (status) {
  ToolStatus.running || ToolStatus.awaitingApproval => StateDotState.ongoing,
  ToolStatus.succeeded => StateDotState.done,
  ToolStatus.failed => StateDotState.error,
  ToolStatus.denied => StateDotState.warning,
};

/// The status word a card's secondary line carries.
String statusLabelOf(ToolStatus status) => switch (status) {
  ToolStatus.running || ToolStatus.awaitingApproval => 'Running',
  ToolStatus.succeeded => 'Done',
  ToolStatus.failed => 'Failed',
  ToolStatus.denied => 'Declined',
};

/// The response text of a finished delegation, or null when it has none yet.
///
/// The middleware returns `{response: …, artifacts: …}`; a sub-agent failure
/// arrives as the response text itself (it resolves rather than throws), so
/// this is the dock's body in every case but a call that is still running.
String? delegationResponseOf(Object? output) {
  if (output is Map && output['response'] is String) {
    return output['response'] as String;
  }
  return null;
}

/// Collapse whitespace to single spaces — the source's `flatten`.
String flatten(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// First [limit] characters with an ellipsis — the source's `preview`.
String preview(String text, int limit) =>
    text.length > limit ? '${text.substring(0, limit)}…' : text;

/// The task of a delegation, flattened to one line — the source's live-args
/// preview, promoted to the card's command line because it is the most
/// identifying thing a delegation carries.
String taskPreviewOf(Map<String, dynamic> arguments, [int limit = 80]) {
  final task = arguments['task'];
  if (task is! String) return '';
  final flat = flatten(task);
  return flat.isEmpty ? '' : preview(flat, limit);
}

/// The first error line of [node], or empty — the same first-line rule the
/// transcript's tool rows use, so a failure reads identically in both places.
String failureLineOf(ToolCallNode node) {
  final message = node.errorMessage ?? '';
  final newline = message.indexOf('\n');
  return newline == -1 ? message : message.substring(0, newline);
}

/// The delegation's elapsed time — running cards are read against the wall
/// clock, settled ones against their own `finishedAt`. Null when the transcript
/// was rebuilt from a snapshot, which does not record times.
Duration? elapsedOf(ToolCallNode node) {
  final start = node.startedAt;
  if (start == null) return null;
  return (node.finishedAt ?? DateTime.now()).difference(start);
}

/// Elapsed time in at most two adjacent units — the source's
/// `formatJobDuration` without its translator. A delegation that outlives an
/// hour is already exceptional, so hours is the widest unit.
String formatDuration(Duration elapsed) {
  final total = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
  final seconds = total % 60;
  final minutes = total ~/ 60 % 60;
  final hours = total ~/ 3600;
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

// ---- The tab ----------------------------------------------------------------

/// How long a kill button stays armed before it needs re-confirming.
const _killArmDuration = Duration(seconds: 3);

class SubagentTab extends StatefulWidget {
  const SubagentTab({super.key, required this.workbench, required this.tab});

  final WorkbenchController workbench;
  final SidebarTab tab;

  @override
  State<SubagentTab> createState() => _SubagentTabState();
}

class _SubagentTabState extends State<SubagentTab> {
  ConversationController? _conversation;

  /// The delegation whose response the dock is showing, by node id.
  String? _selected;

  /// The card whose kill button is armed, by node id.
  String? _armed;

  /// The elapsed clock — the source's per-second `now` tick, which runs only
  /// while a live card is on screen so a hidden tab costs nothing.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    widget.workbench.addListener(_onWorkbench);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final conversation = SubagentHost.of(context);
    if (conversation != _conversation) {
      _conversation?.removeListener(_onConversation);
      _conversation = conversation;
      conversation.addListener(_onConversation);
      // A host swap is a new conversation: the selection and the armed kill
      // belonged to the old one.
      _selected = null;
      _armed = null;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _conversation?.removeListener(_onConversation);
    widget.workbench.removeListener(_onWorkbench);
    super.dispose();
  }

  /// A layout write can make this tab visible (the pane activated it) or hide
  /// it, and only a visible card needs its clock ticking.
  void _onWorkbench() => _reconcileTicker();

  void _onConversation() {
    if (mounted) setState(() {});
    _reconcileTicker();
  }

  bool get _visible {
    final pane = widget.workbench.state.paneOf(widget.tab.id);
    return pane != null && pane.active == widget.tab.id;
  }

  bool _hasLive(List<ToolCallNode> delegations) =>
      delegations.any((node) => !node.status.isSettled);

  void _reconcileTicker() {
    final live = _hasLive(_delegations());
    if (live && _visible && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if ((!live || !_visible) && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  List<ToolCallNode> _delegations() {
    final conversation = _conversation;
    if (conversation == null) return const [];
    return [
      for (final node in conversation.nodes)
        if (node is ToolCallNode && isDelegation(node)) node,
    ];
  }

  ToolCallNode? _findSelected(List<ToolCallNode> delegations) {
    for (final node in delegations) {
      if (node.id == _selected) return node;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final conversation = _conversation;
    final delegations = _delegations();
    final selected = _findSelected(delegations);
    final liveCount = delegations
        .where((node) => !node.status.isSettled)
        .length;

    return DecoratedBox(
      decoration: BoxDecoration(color: color.bgLayer2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(count: delegations.length, liveCount: liveCount),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(6, 2, 6, 8),
              children: [
                _RootCard(
                  conversation: conversation,
                  onTap: () => setState(() => _selected = null),
                ),
                if (delegations.isEmpty)
                  const _EmptyState()
                else
                  _ChildrenBlock(
                    delegations: delegations,
                    selectedId: selected?.id,
                    armedId: _armed,
                    onTap: (node) => setState(
                      () => _selected = _selected == node.id ? null : node.id,
                    ),
                    onKill: _kill,
                  ),
              ],
            ),
          ),
          if (selected != null)
            _OutputDock(
              node: selected,
              onClose: () => setState(() => _selected = null),
            ),
        ],
      ),
    );
  }

  /// The two-click kill of the source's job rows: the first click arms for
  /// [_killArmDuration], the second confirms. Stopping the delegation stops
  /// the whole turn — see the file header.
  void _kill(ToolCallNode node) {
    if (_armed != node.id) {
      setState(() => _armed = node.id);
      Timer(_killArmDuration, () {
        if (mounted && _armed == node.id) setState(() => _armed = null);
      });
      return;
    }
    setState(() => _armed = null);
    _conversation?.stop();
  }
}

// ---- The pieces --------------------------------------------------------------

/// The page header — `.subagentHeader`: title, then the descendant count badge.
class _Header extends StatelessWidget {
  const _Header({required this.count, required this.liveCount});

  final int count;
  final int liveCount;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final noun = count == 1 ? 'subagent' : 'subagents';
    return Container(
      height: 36,
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Sub-agents',
              style: DswType.s14.copyWith(color: color.labelSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (count > 0)
            Text(
              liveCount > 0
                  ? '$count $noun · $liveCount running'
                  : '$count $noun',
              style: DswType.xxxs11.copyWith(color: color.labelTertiary),
            ),
        ],
      ),
    );
  }
}

/// The main agent's card — the topology's root. Clicking it clears the
/// selection, which is this port's answer to the source's "jump back to the
/// main session": the dock is the only thing the jump would close.
class _RootCard extends StatefulWidget {
  const _RootCard({required this.conversation, required this.onTap});

  final ConversationController? conversation;
  final VoidCallback onTap;

  @override
  State<_RootCard> createState() => _RootCardState();
}

class _RootCardState extends State<_RootCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final running = widget.conversation?.isBusy ?? false;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.fromLTRB(11, 7, 8, 7),
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: StateDot(
                  state: running
                      ? StateDotState.ongoing
                      : StateDotState.done,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Main agent',
                      style: DswType.s14.copyWith(color: color.labelPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      running ? 'Running' : 'Idle',
                      style: DswType.xxxs11.copyWith(
                        color: color.labelTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The children of the root, with the source's tree connector lines drawn
/// around each card — see `_Connector` for the geometry.
class _ChildrenBlock extends StatelessWidget {
  const _ChildrenBlock({
    required this.delegations,
    required this.selectedId,
    required this.armedId,
    required this.onTap,
    required this.onKill,
  });

  final List<ToolCallNode> delegations;
  final String? selectedId;
  final String? armedId;
  final void Function(ToolCallNode) onTap;
  final void Function(ToolCallNode) onKill;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // `.subagentChildren`: margin-left 18, padding-left 4.
      padding: const EdgeInsets.only(left: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < delegations.length; index++)
            _Connector(
              first: index == 0,
              last: index == delegations.length - 1,
              child: _DelegationCard(
                node: delegations[index],
                selected: delegations[index].id == selectedId,
                armed: delegations[index].id == armedId,
                onTap: onTap,
                onKill: onKill,
              ),
            ),
        ],
      ),
    );
  }
}

/// The connector hairlines of one child, drawn in front of the card so a hover
/// fill cannot eat them — the CSS draws its `::before` pseudo-elements above
/// the row's own background for the same reason.
///
/// The geometry is the source's, translated: the vertical rail runs at the
/// card's left edge minus 4 (`.subagentNode::before`, `left: -4px`), from the
/// card's top to its bottom — but only to 17px on the last card, which is
/// where the source stops the rail. The elbow is a horizontal stub at the
/// card's y=16 (`.subagentRow::before`, `top: 16px`), reaching 14px into the
/// card. The first card also carries the stub that ties the block to the root
/// (`.subagentChildren::before`, `top: -26px`), which paints above the card's
/// top edge; that is fine inside the scroll view, which only clips at the
/// viewport — the source's sticky dock aside, the effect is identical.
class _Connector extends StatelessWidget {
  const _Connector({required this.first, required this.last, required this.child});

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return CustomPaint(
      foregroundPainter: _ConnectorPainter(
        line: color.borderL2,
        first: first,
        last: last,
      ),
      child: child,
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  const _ConnectorPainter({
    required this.line,
    required this.first,
    required this.last,
  });

  final Color line;
  final bool first;
  final bool last;

  @override
  void paint(Canvas canvas, Size size) {
    final rail = Offset(-4, 0);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // The rail down this card's left edge, stopping at the last elbow.
    final bottom = last ? 17.0 : size.height;
    canvas.drawLine(rail, Offset(rail.dx, bottom), paint);
    // The elbow into the card, at the state dot's centre line.
    canvas.drawLine(const Offset(-4, 16), const Offset(10, 16), paint);
    // The stub up to the root card — only the block's first child carries it.
    if (first) {
      canvas.drawLine(rail, const Offset(-4, -26), paint);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.line != line || old.first != first || old.last != last;
}

/// One delegation card: the topology row and the job row fused, since here
/// they are the same thing — see the file header. The command line carries the
/// agent as a kind chip (`.jobsKind`) beside the task in the code face
/// (`.jobsLabel`); the secondary line below carries status and elapsed.
class _DelegationCard extends StatefulWidget {
  const _DelegationCard({
    required this.node,
    required this.selected,
    required this.armed,
    required this.onTap,
    required this.onKill,
  });

  final ToolCallNode node;
  final bool selected;
  final bool armed;
  final void Function(ToolCallNode) onTap;
  final void Function(ToolCallNode) onKill;

  @override
  State<_DelegationCard> createState() => _DelegationCardState();
}

class _DelegationCardState extends State<_DelegationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final node = widget.node;
    final live = !node.status.isSettled;
    final elapsed = elapsedOf(node);
    final secondary = [
      statusLabelOf(node.status),
      if (elapsed != null) formatDuration(elapsed),
    ].join(' · ');
    final task = taskPreviewOf(node.arguments);

    return Row(
      children: [
        Expanded(
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onTap(node),
              child: Container(
                padding: const EdgeInsets.fromLTRB(11, 6, 8, 6),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? color.interactiveBgActive
                      : _hovered
                      ? color.interactiveBgHover
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: StateDot(state: dotStateOf(node.status)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: color.borderL2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    agentNameOf(node.name),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DswType.xxxsStrong11.copyWith(
                                      color: color.labelTertiary,
                                      height: 14 / 11,
                                    ),
                                  ),
                                ),
                              ),
                              if (task.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    task,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: DswType.xxxs11.copyWith(
                                      color: color.labelPrimary,
                                      fontFamily: dswFontFamilyCode,
                                      fontFamilyFallback:
                                          dswFontFamilyCodeFallback,
                                    ),
                                  ),
                                ),
                              ] else if (live) ...[
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'Thinking…',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            secondary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DswType.xxxs11.copyWith(
                              color: color.labelTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // `.jobsKill` — only a live row can be killed; a settled one has
        // nothing left to stop.
        if (live)
          _KillButton(armed: widget.armed, onTap: () => widget.onKill(node)),
      ],
    );
  }
}

/// The two-click kill button, armed state and all — `.jobsKill` and
/// `.jobsKillArmed`. The armed state swaps the icon for a confirm chip, so a
/// stray click can never stop a turn.
class _KillButton extends StatefulWidget {
  const _KillButton({required this.armed, required this.onTap});

  final bool armed;
  final VoidCallback onTap;

  @override
  State<_KillButton> createState() => _KillButtonState();
}

class _KillButtonState extends State<_KillButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    if (widget.armed) {
      return GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          margin: const EdgeInsets.only(right: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.stateErrorPrimary.withValues(
              alpha: 0.12,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Confirm',
            style: DswType.xxxsStrong11.copyWith(
              color: color.stateErrorPrimary,
            ),
          ),
        ),
      );
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            color: _hovered
                ? color.stateErrorPrimary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            LucideIcons.square,
            size: 12,
            color: _hovered
                ? color.stateErrorPrimary
                : color.labelSecondary,
          ),
        ),
      ),
    );
  }
}

/// `.subagentEmpty`: the block-centred explainer, with its dimmed hint below.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'No sub-agents yet',
            textAlign: TextAlign.center,
            style: DswType.xxs12.copyWith(color: color.labelTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            'Work the main agent delegates will be tracked here.',
            textAlign: TextAlign.center,
            style: DswType.xxxs11.copyWith(color: color.labelDimmed),
          ),
        ],
      ),
    );
  }
}

/// The shared output dock — `.jobsPane`, stuck to the page's bottom so the
/// list scrolls above it. One dock, not a panel per card, keeps the card list
/// compact and stable while many delegations run.
class _OutputDock extends StatelessWidget {
  const _OutputDock({required this.node, required this.onClose});

  final ToolCallNode node;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final live = !node.status.isSettled;
    final failed = node.status == ToolStatus.failed ||
        node.status == ToolStatus.denied;
    final response = delegationResponseOf(node.output);

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 4, 6, 8),
      decoration: BoxDecoration(
        color: color.bgBase,
        border: Border.all(color: color.borderL2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // `.jobsPaneHeader`
          Container(
            height: 28,
            padding: const EdgeInsets.only(left: 10, right: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: color.borderL1)),
            ),
            child: Row(
              children: [
                StateDot(state: dotStateOf(node.status)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    agentNameOf(node.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.xxxs11.copyWith(
                      color: color.labelPrimary,
                      fontFamily: dswFontFamilyCode,
                      fontFamilyFallback: dswFontFamilyCodeFallback,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  statusLabelOf(node.status),
                  style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                ),
                const SizedBox(width: 4),
                _DockCloseButton(onTap: onClose),
              ],
            ),
          ),
          if (live)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'Thinking…',
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            )
          else if (failed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                failureLineOf(node),
                style: DswType.xxxs11.copyWith(
                  color: color.stateErrorPrimary,
                ),
              ),
            )
          else if (response == null || response.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                'No output',
                style: DswType.xxxs11.copyWith(color: color.labelTertiary),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    response,
                    style: DswType.xxxs11.copyWith(
                      color: color.labelPrimary,
                      height: 1.5,
                      fontFamily: dswFontFamilyCode,
                      fontFamilyFallback: dswFontFamilyCodeFallback,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// `.jobsPaneClose`: 20x20, radius 5, hover fill.
class _DockCloseButton extends StatefulWidget {
  const _DockCloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_DockCloseButton> createState() => _DockCloseButtonState();
}

class _DockCloseButtonState extends State<_DockCloseButton> {
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
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Icon(
            LucideIcons.x,
            size: 10,
            color: _hovered ? color.labelPrimary : color.labelSecondary,
          ),
        ),
      ),
    );
  }
}
