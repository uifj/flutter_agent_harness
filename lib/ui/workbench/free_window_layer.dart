// The free-window layer: the workbench's floated tabs, over the conversation.
//
// A port of `DSH-better-sidebar/src/client/FreeWindow.tsx` at one remove. The
// source walks pointer events by hand to write geometry straight into the DOM
// and commits once on release; Flutter has no DOM to write to, so the same
// contract becomes local state — a drag moves THIS window only, per frame, and
// commits to the controller on release. Nothing else rebuilds while a window
// is being dragged, which was the whole point of the source's discipline too.
//
// What the source has and this does not:
//
//   * Dock-on-drop — dragging a window over a pane highlights the pane and
//     releasing docks into it. The dock-back here is the header's right-click
//     menu and the source's own other half; the hover hit-test needs every
//     pane's viewport rect at drag cadence and buys gesture complexity over
//     the menu that already answers the question.
//   * The rAF coalescing — there is no rAF in Flutter, and a setState per
//     pointer event is already one layout per frame.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../host/git.dart';
import '../../host/terminal_manager.dart';
import '../../l10n/locales.dart';
import '../../state/conversation_controller.dart';
import '../../state/side_chat_controller.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../../model/sidebar_state.dart';
import '../../state/workbench_controller.dart';
import 'tab_registry.dart';
import 'tabs/git_tab.dart';
import 'tabs/sidechat_tab.dart';
import 'tabs/subagent_tab.dart';
import 'tabs/terminal_tab.dart';

/// The side-chat controller this layer falls back to when no app passed one —
/// inert (no runner), so a floated side-chat tab without wiring explains
/// itself instead of crashing, and the fallback is stable across rebuilds so
/// the host it rides never swaps mid-conversation.
final _fallbackSideChat = SideChatController();

/// The free-window layer: one [Positioned] child per float, in stacking order,
/// inside the overlay the app frame already floats over everything.
///
/// Sits in the app's overlay rather than inside either Workbench panel: the
/// windows are viewport-addressed and cross both panels, and a layer that
/// scrolled or clipped with a column would strand them. The hosts a tab body
/// expects are mounted here for the same reason the Workbench mounts them —
/// bodies are built by the global registry and look their scopes up from
/// their own context.
class FreeWindowLayer extends StatelessWidget {
  FreeWindowLayer({
    super.key,
    required this.workbench,
    required this.conversation,
    this.sideChat,
    TerminalManager? terminals,
    GitRunner? git,
  }) : terminals = terminals ?? TerminalManager(),
       git = git ?? runGit;

  final WorkbenchController workbench;

  /// The transcript the sub-agent tab projects its topology from.
  final ConversationController conversation;

  /// The side chat's controller — the app's, so a floated side-chat tab
  /// shares the exchange the docked one shows. Null lets a float built
  /// without one show the tab's no-model page rather than crash.
  final SideChatController? sideChat;

  /// The pty pool the terminal tabs draw from — the app's, so a floated
  /// terminal keeps its shell when the workbench column closes.
  final TerminalManager terminals;

  /// How the git tab talks to git.
  final GitRunner git;

  @override
  Widget build(BuildContext context) => GitHost(
    runner: git,
    child: TerminalHost(
      manager: terminals,
      child: SubagentHost(
        conversation: conversation,
        child: SideChatHost(
          chat: sideChat ?? _fallbackSideChat,
          child: AnimatedBuilder(
            animation: workbench,
            builder: (context, _) {
              final floats = workbench.state.floats;
              if (floats.isEmpty) return const SizedBox.shrink();
              return LayoutBuilder(
                builder: (context, constraints) => Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final float in floats)
                      Positioned(
                        left: float.x,
                        top: float.y,
                        width: float.w,
                        height: float.h,
                        child: _FreeWindow(
                          workbench: workbench,
                          float: float,
                          vw: constraints.maxWidth,
                          vh: constraints.maxHeight,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _FreeWindow extends StatefulWidget {
  const _FreeWindow({
    required this.workbench,
    required this.float,
    required this.vw,
    required this.vh,
  });

  final WorkbenchController workbench;
  final FloatWindow float;

  /// The layer's size, which is what the geometry clamps against.
  final double vw;
  final double vh;

  @override
  State<_FreeWindow> createState() => _FreeWindowState();
}

class _FreeWindowState extends State<_FreeWindow> {
  /// The press a drag starts from, and the geometry it started at — pointer
  /// events, not a pan recogniser, because the drag is absolute (event minus
  /// press) and a recogniser's slop would eat the first move of every drag.
  Offset? _movePress;
  double _moveStartX = 0;
  double _moveStartY = 0;
  Offset? _resizePress;
  double _resizeStartW = 0;
  double _resizeStartH = 0;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final tab = widget.float.tab;
    final descriptor = descriptorFor(tab.type);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.bgLayer2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.borderL2),
        boxShadow: DswShadow.lv3,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            Column(
              children: [
                _header(
                  context,
                  color,
                  descriptor?.icon ?? LucideIcons.file_text,
                ),
                Expanded(
                  child: descriptor?.build(context, widget.workbench, tab) ??
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            context.tr('unknownTabType', {'type': tab.type}),
                            textAlign: TextAlign.center,
                            style: DswType.xs13.copyWith(
                              color: color.labelTertiary,
                            ),
                          ),
                        ),
                      ),
                ),
              ],
            ),
            Positioned(right: 0, bottom: 0, child: _resizeHandle(color)),
          ],
        ),
      ),
    );
  }

  /// The SE corner: the one resize affordance, per the source.
  Widget _resizeHandle(DswAlias color) => Listener(
    onPointerDown: (event) {
      _resizePress = event.position;
      _resizeStartW = widget.float.w;
      _resizeStartH = widget.float.h;
    },
    onPointerMove: (event) {
      final press = _resizePress;
      if (press == null) return;
      widget.workbench.resizeFloat(
        widget.float.id,
        _resizeStartW + event.position.dx - press.dx,
        _resizeStartH + event.position.dy - press.dy,
        widget.vw,
        widget.vh,
      );
    },
    onPointerUp: (_) => _resizePress = null,
    onPointerCancel: (_) => _resizePress = null,
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeDownRight,
      child: SizedBox(
        width: 16,
        height: 16,
        child: Center(
          child: Icon(
            LucideIcons.grip,
            size: 12,
            color: color.labelTertiary,
          ),
        ),
      ),
    ),
  );

  /// The title bar: icon, title, close — and the two gestures it owns, drag to
  /// move and right-click to dock or close.
  Widget _header(BuildContext context, DswAlias color, IconData icon) {
    final tab = widget.float.tab;
    return Listener(
      onPointerDown: (event) {
        // Any press raises — the stacking order is the array's order, and a
        // window the user is touching is the one they mean to see.
        widget.workbench.raiseFloat(widget.float.id);
        _movePress = event.position;
        _moveStartX = widget.float.x;
        _moveStartY = widget.float.y;
      },
      onPointerMove: (event) {
        final press = _movePress;
        if (press == null) return;
        widget.workbench.moveFloat(
          widget.float.id,
          _moveStartX + event.position.dx - press.dx,
          _moveStartY + event.position.dy - press.dy,
          widget.vw,
          widget.vh,
        );
      },
      onPointerUp: (_) => _movePress = null,
      onPointerCancel: (_) => _movePress = null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onSecondaryTapDown: (details) => _menu(details.globalPosition),
        child: Container(
          height: 32,
          padding: const EdgeInsets.only(left: 10, right: 4),
          decoration: BoxDecoration(
            color: color.bgLayer1,
            border: Border(bottom: BorderSide(color: color.borderL1)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 12, color: color.labelSecondary),
              const SizedBox(width: 6),
              Expanded(
              child: Text(
                tab.title.isEmpty ? context.tr('untitled') : tab.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xxs12.copyWith(color: color.labelPrimary),
              ),
            ),
              const SizedBox(width: 4),
              _CloseButton(onTap: () {
                widget.workbench.closeFloatByTab(widget.float.tab.id);
              }),
            ],
          ),
        ),
      ),
    );
  }

  /// The header's right-click menu: the dock-back and the close, the two
  /// things a floating window wants said about it.
  Future<void> _menu(Offset global) async {
    final color = context.dsw;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(global, global),
        Offset.zero & overlay.size,
      ),
      constraints: const BoxConstraints(minWidth: 180),
      color: color.menu,
      items: [
        PopupMenuItem(
          value: 'dock',
          child: Row(
            children: [
              Icon(
                LucideIcons.panel_right,
                size: 12,
                color: color.labelSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                context.tr('dockToSidebar'),
                style: DswType.xs13.copyWith(color: color.labelPrimary),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'close',
          child: Row(
            children: [
              Icon(LucideIcons.x, size: 12, color: color.labelSecondary),
              const SizedBox(width: 5),
              Text(
                context.tr('close'),
                style: DswType.xs13.copyWith(color: color.labelPrimary),
              ),
            ],
          ),
        ),
      ],
    );
    switch (result) {
      case 'dock':
        widget.workbench.dockFloat(widget.float.id);
      case 'close':
        widget.workbench.closeFloatByTab(widget.float.tab.id);
      case null:
        break;
    }
  }
}

/// The header's close affordance — the `_CloseButton` shape the tab strip uses,
/// at the strip's own scale.
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
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            LucideIcons.x,
            size: 11,
            color: _hovered ? color.labelPrimary : color.labelTertiary,
          ),
        ),
      ),
    );
  }
}
