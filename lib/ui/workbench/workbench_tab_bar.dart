// One pane's tab strip.
//
// A port of `DSH-better-sidebar/src/client/TabBar.tsx`. The gestures it carries,
// and where each comes from:
//
//   * Click to activate, middle-click to close (`TabBar.tsx:96-104`). Middle-click
//     is the one browsers and editors share, and it is why this uses a raw
//     [Listener] rather than [GestureDetector]: Flutter's tap recognisers only
//     report the primary button.
//   * Right-click opens the per-tab context menu (`TabBar.tsx:106-172`): close,
//     close others, close all, and the send-to-other-panel twin of dragging the
//     tab there. The source's float item waits for free windows to exist (C3).
//   * The `+` at the strip's right end opens the new-tab menu over the openable
//     types (`TabBar.tsx:234-265`): explorer, terminal, git, sub-agents — this
//     panel's own openers, which is why the workbench needs no header row of
//     them. An empty pane shows the same options as cards (`split-pane.tsx:113`).
//   * Drag a tab within the strip to reorder, or onto another pane to move it
//     there. Both are the same [Draggable] payload; which one happens is decided
//     by whichever [DragTarget] takes the drop, so the strip does not need to know
//     the layout and `split_view.dart` does not need to know about tabs.
//   * Horizontal scroll, because a pane in a 300px column overflows at three tabs
//     and a strip that clips them makes them unreachable.
//
// Not ported: the source's overflow menu. It is a menu over gestures that
// already exist here; the strip scrolls instead.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../../model/sidebar_tab.dart';
import '../../model/split_node.dart';
import '../../state/workbench_controller.dart';
import 'tab_registry.dart';
import 'workbench_prefs_scope.dart';
import '../primitives/menu.dart';
import '../primitives/tappable.dart';

/// Strip height — tall enough that the 32px circular controls sit in it
/// comfortably, matching the sidebar session row rhythm. One line of chrome, so
/// the seat rides the text step: pinned at 36 the tab title wanted 40.0 of the
/// 33.5 left inside it once the system amplified text past 1.8x.
const tabBarHeight = 36.0;

/// What a tab drag carries: enough to run [SidebarState.moveTab] without asking
/// the tree where the tab came from, which would be a second answer that can
/// disagree with the first.
class TabDrag {
  const TabDrag({required this.fromPane, required this.tabId});

  final String fromPane;
  final String tabId;
}

class WorkbenchTabBar extends StatelessWidget {
  const WorkbenchTabBar({
    super.key,
    required this.workbench,
    required this.pane,
    required this.showSplitControls,
  });

  final WorkbenchController workbench;
  final SidebarLeaf pane;

  /// Whether to offer the split controls. Off for a pane that is alone in the
  /// column at its minimum width, where a split would produce two panes too
  /// narrow to read.
  final bool showSplitControls;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: tabBarHeight * MediaQuery.textScalerOf(context).scale(1),
      decoration: BoxDecoration(
        color: color.bgLayer1,
        border: Border(bottom: BorderSide(color: color.borderL1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              primary: false,
              itemCount: pane.tabs.length,
              itemBuilder: (context, index) {
                final tab = pane.tabs[index];
                return _TabChip(
                  key: ValueKey(tab.id),
                  workbench: workbench,
                  paneId: pane.id,
                  tab: tab,
                  index: index,
                  active: tab.id == pane.active,
                );
              },
            ),
          ),
          // The trailing drop zone: releasing a tab past the last one appends it
          // here rather than falling through to the pane body, which would move it
          // to this pane at an arbitrary index.
          _AppendTarget(workbench: workbench, paneId: pane.id),
          if (showSplitControls) ...[
            _StripButton(
              icon: LucideIcons.columns_2,
              tooltip: AppLocalizations.of(context).splitDown,
              rotated: false,
              onTap: () => workbench.splitPane(SplitDirection.col),
            ),
            _StripButton(
              icon: LucideIcons.columns_2,
              tooltip: AppLocalizations.of(context).splitRight,
              rotated: true,
              onTap: () => workbench.splitPane(SplitDirection.row),
            ),
          ],
          // The `+` menu, after the tabs — the strip's one opener, so the panel
          // needs no header row of them.
          _NewTabButton(workbench: workbench),
        ],
      ),
    );
  }
}

/// The `+`: the new-tab menu over the openable types, in registry order.
///
/// Editor and diff are deliberately absent — they are response tabs (a file
/// opens because something asked for it), which is the source's own `hidden`
/// rule for the `+` menu (`builtins/tabs.tsx`). Explorer is disabled rather
/// than hidden when there is no workspace, matching `available` returning
/// false (`Sidebar.tsx:162-179`). A type the user switched off in the prefs is
/// dropped from the list entirely — the source's own rule: hidden from the `+`
/// menu, refused at open, never closed once open.
class _NewTabButton extends StatelessWidget {
  const _NewTabButton({required this.workbench});

  final WorkbenchController workbench;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final prefs = WorkbenchPrefsScope.of(context);
    final root = workbench.workspaceRoot;
    return DswMenu(
      label: AppLocalizations.of(context).newTab,
      minWidth: 180,
      items: (context) => [
        if (prefs.tabEnabled(BuiltinTabType.explorer))
          DswMenuEntry(
            icon: LucideIcons.folder_open,
            label: AppLocalizations.of(context).explorer,
            // Disabled rather than hidden when there is no workspace, matching
            // `available` returning false (`Sidebar.tsx:162-179`).
            onTap: root == null ? null : () => workbench.openFolder(root),
          ),
        if (prefs.tabEnabled(BuiltinTabType.terminal))
          DswMenuEntry(
            icon: LucideIcons.terminal,
            label: AppLocalizations.of(context).terminal,
            onTap: workbench.openTerminal,
          ),
        if (prefs.tabEnabled(BuiltinTabType.git))
          DswMenuEntry(
            icon: LucideIcons.git_branch,
            label: AppLocalizations.of(context).git,
            onTap: workbench.openGit,
          ),
        if (prefs.tabEnabled(BuiltinTabType.subagent))
          DswMenuEntry(
            icon: LucideIcons.network,
            label: AppLocalizations.of(context).subagents,
            onTap: workbench.openSubagents,
          ),
        if (prefs.tabEnabled(BuiltinTabType.browser))
          DswMenuEntry(
            icon: LucideIcons.globe,
            label: AppLocalizations.of(context).browser,
            onTap: workbench.openBrowserUntitled,
          ),
        if (prefs.tabEnabled(BuiltinTabType.sidechat))
          DswMenuEntry(
            icon: LucideIcons.message_square_plus,
            label: AppLocalizations.of(context).sidechat,
            onTap: workbench.openSideChat,
          ),
      ],
      trigger: (context) => Container(
        width: 30,
        height: tabBarHeight * MediaQuery.textScalerOf(context).scale(1),
        color: Colors.transparent,
        child: Icon(
          LucideIcons.plus,
          size: DswShape.iconSm,
          color: color.labelSecondary,
        ),
      ),
    );
  }
}

class _TabChip extends StatefulWidget {
  const _TabChip({
    super.key,
    required this.workbench,
    required this.paneId,
    required this.tab,
    required this.index,
    required this.active,
  });

  final WorkbenchController workbench;
  final String paneId;
  final SidebarTab tab;
  final int index;
  final bool active;

  @override
  State<_TabChip> createState() => _TabChipState();
}

class _TabChipState extends State<_TabChip> {
  bool _hovered = false;
  bool _focused = false;

  /// Where the last right-click landed, globally. The context menu owns the
  /// right button and keeps the position to itself, so the one action that
  /// needs it — floating the window under the click — reads it off the pointer.
  Offset? _secondaryAt;

  /// True while a tab is hovering the left half of this chip, so the insertion
  /// point is visible before the drop rather than guessed.
  bool _insertBefore = false;
  bool _dropping = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final descriptor = descriptorFor(widget.tab.type);
    final chip = _chip(color, descriptor?.icon ?? LucideIcons.file_text);

    return DragTarget<TabDrag>(
      onWillAcceptWithDetails: (details) {
        // Its own position is not a move; accepting it would make the chip flash
        // an insertion bar for a drop that does nothing.
        if (details.data.tabId == widget.tab.id) return false;
        setState(() => _dropping = true);
        return true;
      },
      onLeave: (_) => setState(() => _dropping = false),
      onMove: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.offset);
        final before = local.dx < box.size.width / 2;
        if (before != _insertBefore) setState(() => _insertBefore = before);
      },
      onAcceptWithDetails: (details) {
        setState(() => _dropping = false);
        widget.workbench.moveTab(
          details.data.fromPane,
          details.data.tabId,
          widget.paneId,
          _insertBefore ? widget.index : widget.index + 1,
        );
      },
      builder: (context, candidate, rejected) => Stack(
        children: [
          chip,
          if (_dropping)
            Positioned(
              top: 0,
              bottom: 0,
              left: _insertBefore ? 0 : null,
              right: _insertBefore ? null : 0,
              child: Container(width: 2, color: color.brandPrimary),
            ),
        ],
      ),
    );
  }

  Widget _chip(DswAlias color, IconData icon) {
    final fill = widget.active
        ? color.bgLayer2
        : _hovered || _focused
        ? color.interactiveBgHover
        : Colors.transparent;

    final body = AnimatedContainer(
      duration: DswMotion.respecting(context, DswMotion.fast),
      curve: DswMotion.easeInOut,
      height: tabBarHeight * MediaQuery.textScalerOf(context).scale(1),
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          top: BorderSide(
            color: widget.active ? color.labelTertiary : Colors.transparent,
            width: 1.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: DswShape.iconTiny,
            color: widget.active ? color.labelSecondary : color.labelTertiary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              widget.tab.title.isEmpty
                  ? AppLocalizations.of(context).untitled
                  : widget.tab.title,
              style: DswType.xxs12.copyWith(
                color: widget.active
                    ? color.labelPrimary
                    : color.labelSecondary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
          const SizedBox(width: 2),
          // The close affordance holds its 18px whether shown or not: revealing it
          // on hover must not shift the title out from under the pointer.
          SizedBox.square(
            dimension: 18,
            child: AnimatedOpacity(
              opacity: _hovered || widget.active ? 1 : 0,
              duration: DswMotion.respecting(context, DswMotion.fast),
              child: _CloseButton(
                onTap: _close,
                label: AppLocalizations.of(context).close,
              ),
            ),
          ),
        ],
      ),
    );

    final draggable = Draggable<TabDrag>(
      data: TabDrag(fromPane: widget.paneId, tabId: widget.tab.id),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: _Feedback(title: widget.tab.title, icon: icon, color: color),
      // Left in place rather than removed: a strip that reflows the moment a drag
      // starts moves the drop targets out from under the pointer.
      childWhenDragging: Opacity(opacity: 0.4, child: body),
      child: body,
    );

    // A tab is selected by click, middle-click-to-close, right-click menu and
    // drag-reorder. Keyboard parity is added here without disturbing those:
    // the FocusableActionDetector + Semantics wrap the existing tree, so Tab
    // lands on the chip, Enter/Space activates it, and VoiceOver announces it
    // as a selected tab. The inner Listener/GestureDetector/drag stay as-is.
    return FocusableActionDetector(
      onFocusChange: (focused) => setState(() => _focused = focused),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.workbench.activateTab(widget.paneId, widget.tab.id);
            return null;
          },
        ),
      },
      child: Semantics(
        selected: widget.active,
        label: widget.tab.path ?? widget.tab.title,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Listener(
            // Middle-click to close: not a button Flutter's tap recognisers
            // report, so the raw pointer event is the only way to see it. The
            // secondary press is noted for the same reason — the context menu
            // below owns the right button, and "float under the click" needs to
            // know where that click was.
            onPointerDown: (event) {
              if (event.buttons & kMiddleMouseButton != 0) _close();
              if (event.buttons & kSecondaryMouseButton != 0) {
                _secondaryAt = event.position;
              }
            },
            child: DswContextMenu(
              minWidth: 190,
              items: (context) => _menuItems(context),
              child: GestureDetector(
                onTap: () =>
                    widget.workbench.activateTab(widget.paneId, widget.tab.id),
                behavior: HitTestBehavior.opaque,
                child: Tooltip(
                  message: widget.tab.path ?? widget.tab.title,
                  child: draggable,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _close() => widget.workbench.closeTab(widget.paneId, widget.tab.id);

  /// The per-tab context menu: the close family, then the send that stands in
  /// for dragging the tab to the other panel, then the float. "Close others"
  /// needs others to be there, or it would read as a no-op on a one-tab strip.
  List<DswMenuEntry> _menuItems(BuildContext context) {
    final state = widget.workbench.state;
    final inBottom = state.bottomPanes.any((pane) => pane.id == widget.paneId);
    final others = state.paneOf(widget.tab.id)?.tabs.length ?? 1;
    return [
      DswMenuEntry(
        icon: LucideIcons.x,
        label: AppLocalizations.of(context).close,
        onTap: _close,
      ),
      if (others > 1)
        DswMenuEntry(
          icon: LucideIcons.list_x,
          label: AppLocalizations.of(context).closeOthers,
          onTap: () =>
              widget.workbench.closeOtherTabs(widget.paneId, widget.tab.id),
        ),
      DswMenuEntry(
        icon: LucideIcons.square_x,
        label: AppLocalizations.of(context).closeAll,
        onTap: () => widget.workbench.closeAllTabs(widget.paneId),
      ),
      const DswMenuEntry.divider(),
      DswMenuEntry(
        icon: inBottom
            ? LucideIcons.arrow_up_from_line
            : LucideIcons.arrow_down_to_line,
        label: inBottom
            ? AppLocalizations.of(context).sendToSidePanel
            : AppLocalizations.of(context).sendToBottomPanel,
        onTap: () =>
            widget.workbench.sendTabToOtherPanel(widget.paneId, widget.tab.id),
      ),
      DswMenuEntry(
        icon: LucideIcons.picture_in_picture_2,
        label: AppLocalizations.of(context).floatInWindow,
        onTap: _float,
      ),
    ];
  }

  /// Floats this tab, centred on the right-click that opened the menu — the
  /// window lands under the pointer the same way it would under a drag, minus
  /// the drag. The viewport is the overlay's own size, because the float layer
  /// lives there.
  void _float() {
    final at = _secondaryAt;
    if (at == null) return;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final local = overlay.globalToLocal(at);
    widget.workbench.floatTab(
      widget.tab.id,
      local.dx,
      local.dy,
      overlay.size.width,
      overlay.size.height,
    );
  }
}

/// The strip's trailing space, which appends on drop.
class _AppendTarget extends StatefulWidget {
  const _AppendTarget({required this.workbench, required this.paneId});

  final WorkbenchController workbench;
  final String paneId;

  @override
  State<_AppendTarget> createState() => _AppendTargetState();
}

class _AppendTargetState extends State<_AppendTarget> {
  bool _dropping = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DragTarget<TabDrag>(
      onWillAcceptWithDetails: (_) {
        setState(() => _dropping = true);
        return true;
      },
      onLeave: (_) => setState(() => _dropping = false),
      onAcceptWithDetails: (details) {
        setState(() => _dropping = false);
        widget.workbench.moveTab(
          details.data.fromPane,
          details.data.tabId,
          widget.paneId,
        );
      },
      builder: (context, candidate, rejected) => Container(
        width: 24,
        height: tabBarHeight * MediaQuery.textScalerOf(context).scale(1),
        color: _dropping ? color.interactiveBgHover : Colors.transparent,
      ),
    );
  }
}

/// What follows the pointer during a tab drag: the chip, shrunk, so it is obvious
/// what is being moved without the feedback layer covering the drop targets.
class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.title,
    required this.icon,
    required this.color,
  });

  final String title;
  final IconData icon;
  final DswAlias color;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: 0.9,
    child: Container(
      // One line of chrome, and the ruler only reaches it from above the
      // Navigator: a nailed 24 left 22.0 inside the border for a label that
      // wants 32.0 at 1.8x and 40.0 at 2.2x.
      height: 24 * MediaQuery.textScalerOf(context).scale(1),
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.bgLayer3,
        borderRadius: BorderRadius.circular(DswShape.inset),
        border: Border.all(color: color.borderL2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DswShape.iconTiny, color: color.labelSecondary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              style: DswType.xxs12.copyWith(color: color.labelPrimary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap, required this.label});

  final VoidCallback onTap;

  /// The accessible name; the X glyph alone says nothing to VoiceOver.
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return DswHoverTap(
      onTap: onTap,
      semanticLabel: label,
      excludeSemantics: true,
      builder: (context, hovered, _) => Container(
        decoration: BoxDecoration(
          color: hovered ? color.interactiveBgActive : Colors.transparent,
          borderRadius: BorderRadius.circular(DswShape.inset),
        ),
        child: Center(
          child: Icon(
            LucideIcons.x,
            size: DswShape.iconTiny,
            color: hovered ? color.labelPrimary : color.labelTertiary,
          ),
        ),
      ),
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton({
    required this.icon,
    required this.tooltip,
    required this.rotated,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;

  /// Material ships one split glyph; a quarter turn is what distinguishes "down"
  /// from "right" without a second icon that does not exist.
  final bool rotated;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Tooltip(
      message: tooltip,
      child: DswHoverTap(
        onTap: onTap,
        semanticLabel: tooltip,
        excludeSemantics: true,
        builder: (context, hovered, _) {
          final glyph = Icon(
            icon,
            size: DswShape.iconSm,
            color: hovered ? color.labelSecondary : color.labelTertiary,
          );
          return Container(
            width: 22,
            height: tabBarHeight * MediaQuery.textScalerOf(context).scale(1),
            color: hovered ? color.interactiveBgHover : Colors.transparent,
            child: Center(
              child: rotated
                  ? RotatedBox(quarterTurns: 1, child: glyph)
                  : glyph,
            ),
          );
        },
      ),
    );
  }
}
