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

import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../model/sidebar_tab.dart';
import '../model/split_node.dart';
import '../state/workbench_controller.dart';
import 'tab_registry.dart';

/// Strip height — the source's 34px band (`sidebar.module.css:343`), tall
/// enough that the 28px circular controls sit in it at top:3.
const tabBarHeight = 34.0;

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
    this.reserveTrailing = 0,
  });

  final WorkbenchController workbench;
  final SidebarLeaf pane;

  /// Whether to offer the split controls. Off for a pane that is alone in the
  /// column at its minimum width, where a split would produce two panes too
  /// narrow to read.
  final bool showSplitControls;

  /// Width pinned at the strip's right end for chrome that is not the strip's
  /// own — the panel toggle cluster squeezing into the open panel's top-right
  /// (`sidebar.module.css:83-85` reserves 72px the same way).
  final double reserveTrailing;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Container(
      height: tabBarHeight,
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
              tooltip: 'Split down',
              rotated: false,
              onTap: () => workbench.splitPane(SplitDirection.col),
            ),
            _StripButton(
              icon: LucideIcons.columns_2,
              tooltip: 'Split right',
              rotated: true,
              onTap: () => workbench.splitPane(SplitDirection.row),
            ),
          ],
          // The `+` menu, after the tabs — the strip's one opener, so the panel
          // needs no header row of them.
          _NewTabButton(workbench: workbench),
          SizedBox(width: reserveTrailing),
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
/// false (`Sidebar.tsx:162-179`).
class _NewTabButton extends StatelessWidget {
  const _NewTabButton({required this.workbench});

  final WorkbenchController workbench;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return PopupMenuButton<String>(
      tooltip: 'New tab',
      position: PopupMenuPosition.under,
      constraints: const BoxConstraints(minWidth: 180),
      onSelected: (id) {
        switch (id) {
          case 'explorer':
            final root = workbench.workspaceRoot;
            if (root != null) workbench.openFolder(root);
          case 'terminal':
            workbench.openTerminal();
          case 'git':
            workbench.openGit();
          case 'subagent':
            workbench.openSubagents();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'explorer',
          enabled: workbench.workspaceRoot != null,
          child: _optionRow(
            context,
            LucideIcons.folder_open,
            'Explorer',
            enabled: workbench.workspaceRoot != null,
          ),
        ),
        PopupMenuItem(
          value: 'terminal',
          child: _optionRow(context, LucideIcons.terminal, 'Terminal'),
        ),
        PopupMenuItem(
          value: 'git',
          child: _optionRow(context, LucideIcons.git_branch, 'Source control'),
        ),
        PopupMenuItem(
          value: 'subagent',
          child: _optionRow(context, LucideIcons.network, 'Sub-agents'),
        ),
      ],
      child: Container(
        width: 30,
        height: tabBarHeight,
        color: Colors.transparent,
        child: Icon(
          LucideIcons.plus,
          size: 14,
          color: color.labelSecondary,
        ),
      ),
    );
  }

  Widget _optionRow(
    BuildContext context,
    IconData icon,
    String label, {
    bool enabled = true,
  }) {
    final color = context.dsw;
    final tint = enabled ? color.labelPrimary : color.labelCaption;
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: enabled ? color.labelSecondary : color.labelCaption,
        ),
        const SizedBox(width: 6),
        Text(label, style: DswType.xs13.copyWith(color: tint)),
      ],
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
        : _hovered
        ? color.interactiveBgHover
        : Colors.transparent;

    final body = AnimatedContainer(
      duration: DswMotion.respecting(context, DswMotion.fast),
      curve: DswMotion.easeInOut,
      height: tabBarHeight,
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.only(left: 8, right: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border(
          right: BorderSide(color: color.borderL1),
          // The active tab is marked at the top, the way the source does it, so
          // the strip reads as tabs attached to the body below rather than as a
          // row of buttons.
          top: BorderSide(
            color: widget.active ? color.brandPrimary : Colors.transparent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: widget.active ? color.labelSecondary : color.labelTertiary,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              widget.tab.title.isEmpty ? 'Untitled' : widget.tab.title,
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
          // The close affordance holds its 16px whether shown or not: revealing it
          // on hover must not shift the title out from under the pointer.
          SizedBox.square(
            dimension: 16,
            child: AnimatedOpacity(
              opacity: _hovered || widget.active ? 1 : 0,
              duration: DswMotion.respecting(context, DswMotion.fast),
              child: _CloseButton(onTap: _close),
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        // Middle-click to close: not a button Flutter's tap recognisers report,
        // so the raw pointer event is the only way to see it.
        onPointerDown: (event) {
          if (event.buttons & kMiddleMouseButton != 0) _close();
        },
        child: GestureDetector(
          onTap: () =>
              widget.workbench.activateTab(widget.paneId, widget.tab.id),
          onSecondaryTapDown: _menu,
          behavior: HitTestBehavior.opaque,
          child: Tooltip(
            message: widget.tab.path ?? widget.tab.title,
            waitDuration: const Duration(milliseconds: 600),
            child: draggable,
          ),
        ),
      ),
    );
  }

  void _close() => widget.workbench.closeTab(widget.paneId, widget.tab.id);

  /// Where a right-click's menu opens, at the cursor. Same anchor recipe as
  /// the git tab's row menus.
  RelativeRect _menuAt(Offset global) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    return RelativeRect.fromRect(
      Rect.fromPoints(global, global),
      Offset.zero & overlay.size,
    );
  }

  /// The per-tab context menu: the close family, then the send that stands in
  /// for dragging the tab to the other panel. "Close others" needs others to be
  /// there, or it would read as a no-op on a one-tab strip.
  Future<void> _menu(TapDownDetails details) async {
    final state = widget.workbench.state;
    final inBottom = state.bottomPanes.any((pane) => pane.id == widget.paneId);
    final others = state.paneOf(widget.tab.id)?.tabs.length ?? 1;
    final result = await showMenu<String>(
      context: context,
      position: _menuAt(details.globalPosition),
      constraints: const BoxConstraints(minWidth: 190),
      items: [
        PopupMenuItem(value: 'close', child: _menuRow(LucideIcons.x, 'Close')),
        if (others > 1)
          PopupMenuItem(
            value: 'others',
            child: _menuRow(LucideIcons.list_x, 'Close others'),
          ),
        PopupMenuItem(
          value: 'all',
          child: _menuRow(LucideIcons.square_x, 'Close all'),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'send',
          child: _menuRow(
            inBottom ? LucideIcons.arrow_up_from_line : LucideIcons.arrow_down_to_line,
            inBottom ? 'Send to side panel' : 'Send to bottom panel',
          ),
        ),
      ],
    );
    switch (result) {
      case 'close':
        _close();
      case 'others':
        widget.workbench.closeOtherTabs(widget.paneId, widget.tab.id);
      case 'all':
        widget.workbench.closeAllTabs(widget.paneId);
      case 'send':
        widget.workbench.sendTabToOtherPanel(widget.paneId, widget.tab.id);
      case null:
        break;
    }
  }

  /// One menu row: 12px icon, 5px gap, label — the same shape the git tab's
  /// menus use. The colour is read here rather than in the route so the menu
  /// matches the strip's theme even mid-theme-change.
  Widget _menuRow(IconData icon, String label) {
    final color = context.dsw;
    return Row(
      children: [
        Icon(icon, size: 12, color: color.labelSecondary),
        const SizedBox(width: 5),
        Text(label, style: DswType.xs13.copyWith(color: color.labelPrimary)),
      ],
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
        height: tabBarHeight,
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
      height: 24,
      constraints: const BoxConstraints(maxWidth: 160),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: color.bgLayer3,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.borderL2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.labelSecondary),
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
        // The chip's own tap would otherwise also fire and activate the tab this
        // click is closing.
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          decoration: BoxDecoration(
            color: _hovered ? color.interactiveBgActive : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Center(
            child: Icon(
              LucideIcons.x,
              size: 11,
              color: _hovered ? color.labelPrimary : color.labelTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StripButton extends StatefulWidget {
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
  State<_StripButton> createState() => _StripButtonState();
}

class _StripButtonState extends State<_StripButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final glyph = Icon(
      widget.icon,
      size: 13,
      color: _hovered ? color.labelSecondary : color.labelTertiary,
    );
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 22,
            height: tabBarHeight,
            color: _hovered ? color.interactiveBgHover : Colors.transparent,
            child: Center(
              child: widget.rotated
                  ? RotatedBox(quarterTurns: 1, child: glyph)
                  : glyph,
            ),
          ),
        ),
      ),
    );
  }
}
