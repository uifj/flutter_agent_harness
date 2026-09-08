// One pane: a tab strip, the active tab's body, and the drop zones that move
// tabs between panes.
//
// A port of the pane half of `DSH-better-sidebar/src/client/Sidebar.tsx:820-1010`.
// Two decisions worth stating, because both are choices the source did not have
// to make (React keeps unmounted children's state in its own store):
//
//   * Bodies are kept alive across tab switches, via an [IndexedStack]. Switching
//     away from an editor must not throw away an unsaved buffer, and switching
//     back must not lose the scroll position. In stage five the same property
//     matters more: a terminal that re-mounts is a shell that died.
//   * They are built lazily all the same. [IndexedStack] builds every child, so a
//     pane with twenty editors would read twenty files to show one. A tab is only
//     built once it has been active, and stays built afterwards — which is
//     precisely "alive iff the user has ever looked at it".
//
// The drop geometry is the source's (`split-pane.tsx:40-70`): the outer 25% of
// each edge moves the tab into a new split on that side, the middle stacks it
// into this pane. A quarter is wide enough to hit in a 300px column and narrow
// enough that the common gesture — stack it here — is the default.

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../l10n/locales.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../../model/sidebar_state.dart';
import '../../model/sidebar_tab.dart';
import '../../model/split_node.dart';
import '../../state/workbench_controller.dart';
import 'tab_registry.dart';
import 'workbench_prefs_scope.dart';
import 'workbench_tab_bar.dart';

/// Fraction of the pane each edge zone claims.
const _edgeFraction = 0.25;

class WorkbenchPane extends StatefulWidget {
  const WorkbenchPane({
    super.key,
    required this.workbench,
    required this.pane,
    required this.alone,
    this.reserveTrailing = 0,
  });

  final WorkbenchController workbench;
  final SidebarLeaf pane;

  /// True when this is the only pane in the workbench, which turns off the edge
  /// drop zones: moving a pane's only tab to that pane's own edge would remove
  /// the pane the drop target is in.
  final bool alone;

  /// Width the tab strip keeps free at its right end for the toggle cluster.
  final double reserveTrailing;

  @override
  State<WorkbenchPane> createState() => _WorkbenchPaneState();
}

class _WorkbenchPaneState extends State<WorkbenchPane> {
  /// The body's box, which is what the drop fractions are measured against. The
  /// State's own context would include the tab strip, putting the top edge zone
  /// 30px off.
  final _bodyKey = GlobalKey();

  /// Tabs that have been active at least once, and so have a live body.
  final _built = <String>{};

  /// The zone the hovering tab would land in, or null when nothing is over the
  /// body. Drawn as an overlay so the gesture is legible before the release.
  DropZone? _zone;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final active = widget.pane.active;
    if (active != null) _built.add(active);

    return DecoratedBox(
      decoration: BoxDecoration(color: color.bgLayer2),
      child: Column(
        children: [
          WorkbenchTabBar(
            workbench: widget.workbench,
            pane: widget.pane,
            showSplitControls: widget.pane.tabs.isNotEmpty,
            reserveTrailing: widget.reserveTrailing,
          ),
          Expanded(child: _body(color)),
        ],
      ),
    );
  }

  Widget _body(DswAlias color) {
    final content = widget.pane.tabs.isEmpty
        ? _Welcome(workbench: widget.workbench, paneId: widget.pane.id)
        : _stack();

    return DragTarget<TabDrag>(
      onLeave: (_) => setState(() => _zone = null),
      onMove: (details) {
        final zone = _zoneAt(details.offset);
        if (zone != _zone) setState(() => _zone = zone);
      },
      onAcceptWithDetails: (details) {
        final zone = _zoneAt(details.offset) ?? DropZone.center;
        setState(() => _zone = null);
        final drag = details.data;
        if (zone == DropZone.center) {
          widget.workbench.moveTab(drag.fromPane, drag.tabId, widget.pane.id);
        } else {
          widget.workbench.moveTabToEdge(
            drag.fromPane,
            drag.tabId,
            widget.pane.id,
            zone,
          );
        }
      },
      builder: (context, candidate, rejected) => GestureDetector(
        // Aiming the next open at this pane. A pane with no tabs has none to
        // activate, so a click on the body is the only way to say "here".
        onTapDown: (_) => widget.workbench.focusPane(widget.pane.id),
        behavior: HitTestBehavior.translucent,
        child: Stack(
          key: _bodyKey,
          children: [
            Positioned.fill(child: content),
            if (_zone != null)
              Positioned.fill(child: _ZoneOverlay(zone: _zone!, color: color)),
          ],
        ),
      ),
    );
  }

  /// The lazy, state-preserving body stack. Order follows the pane's tabs so an
  /// index into it is an index into them.
  Widget _stack() {
    final tabs = widget.pane.tabs;
    var index = tabs.indexWhere((tab) => tab.id == widget.pane.active);
    if (index < 0) index = tabs.length - 1;
    return IndexedStack(
      index: index,
      sizing: StackFit.expand,
      children: [
        for (final tab in tabs)
          if (_built.contains(tab.id))
            KeyedSubtree(
              // Keyed by tab id, so reordering the strip moves a body rather than
              // rebuilding two of them into each other's state.
              key: ValueKey(tab.id),
              child:
                  descriptorFor(tab.type)?.build(
                    context,
                    widget.workbench,
                    tab,
                  ) ??
                  _Unknown(type: tab.type),
            )
          else
            KeyedSubtree(key: ValueKey(tab.id), child: const SizedBox.shrink()),
      ],
    );
  }

  /// Which zone the global point [offset] falls in, in this pane's own box.
  DropZone? _zoneAt(Offset offset) {
    final box = _bodyKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    final local = box.globalToLocal(offset);
    final size = box.size;
    if (size.width <= 0 || size.height <= 0) return null;
    if (widget.alone) return DropZone.center;
    final x = local.dx / size.width;
    final y = local.dy / size.height;
    // Horizontal first, matching the source: in a tall narrow column the
    // vertical zones would otherwise swallow the whole body.
    if (x < _edgeFraction) return DropZone.left;
    if (x > 1 - _edgeFraction) return DropZone.right;
    if (y < _edgeFraction) return DropZone.up;
    if (y > 1 - _edgeFraction) return DropZone.down;
    return DropZone.center;
  }
}

/// The tinted half (or whole) the drop would land in.
class _ZoneOverlay extends StatelessWidget {
  const _ZoneOverlay({required this.zone, required this.color});

  final DropZone zone;
  final DswAlias color;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (zone) {
      DropZone.left => Alignment.centerLeft,
      DropZone.right => Alignment.centerRight,
      DropZone.up => Alignment.topCenter,
      DropZone.down => Alignment.bottomCenter,
      DropZone.center => Alignment.center,
    };
    final vertical = zone == DropZone.up || zone == DropZone.down;
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: zone == DropZone.center || vertical ? 1 : 0.5,
          heightFactor: zone == DropZone.center || !vertical ? 1 : 0.5,
          child: AnimatedContainer(
            duration: DswMotion.respecting(context, DswMotion.fast),
            decoration: BoxDecoration(
              color: color.interactiveBgHoverAccent,
              border: Border.all(color: color.brandPrimary, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

/// What an empty pane shows: what it is for, and the two ways to fill it.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.workbench, required this.paneId});

  final WorkbenchController workbench;
  final String paneId;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final focused = workbench.state.activePane == paneId;
    final prefs = WorkbenchPrefsScope.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          // Centred while the pane is tall enough, scrollable the moment it
          // is not: a short bottom panel must not clip the welcome's actions.
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    focused
                        ? context.tr('filesOpenHere')
                        : context.tr('clickToOpenFiles'),
                    textAlign: TextAlign.center,
                    style: DswType.xs13.copyWith(color: color.labelTertiary),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (prefs.tabEnabled(BuiltinTabType.explorer))
                        _WelcomeAction(
                          label: context.tr('explorer'),
                          icon: LucideIcons.folder_open,
                          // Disabled rather than hidden when there is no workspace:
                          // the action is the thing that explains what is missing.
                          onTap: workbench.workspaceRoot == null
                              ? null
                              : () {
                                  workbench.focusPane(paneId);
                                  workbench.openFolder(workbench.workspaceRoot!);
                                },
                        ),
                      if (prefs.tabEnabled(BuiltinTabType.terminal))
                        _WelcomeAction(
                          label: context.tr('terminal'),
                          icon: LucideIcons.terminal,
                          onTap: () {
                            workbench.focusPane(paneId);
                            workbench.openTerminal();
                          },
                        ),
                      if (prefs.tabEnabled(BuiltinTabType.git))
                        _WelcomeAction(
                          label: context.tr('git'),
                          icon: LucideIcons.git_branch,
                          onTap: () {
                            workbench.focusPane(paneId);
                            workbench.openGit();
                          },
                        ),
                      if (prefs.tabEnabled(BuiltinTabType.browser))
                        _WelcomeAction(
                          label: context.tr('browser'),
                          icon: LucideIcons.globe,
                          onTap: () {
                            workbench.focusPane(paneId);
                            workbench.openBrowserUntitled();
                          },
                        ),
                      if (prefs.tabEnabled(BuiltinTabType.sidechat))
                        _WelcomeAction(
                          label: context.tr('sidechat'),
                          icon: LucideIcons.message_square_plus,
                          onTap: () {
                            workbench.focusPane(paneId);
                            workbench.openSideChat();
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeAction extends StatefulWidget {
  const _WelcomeAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;

  /// Null disables the action.
  final VoidCallback? onTap;

  @override
  State<_WelcomeAction> createState() => _WelcomeActionState();
}

class _WelcomeActionState extends State<_WelcomeAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final enabled = widget.onTap != null;
    final tint = enabled ? color.labelSecondary : color.labelTertiary;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _hovered && enabled
                ? color.interactiveBgHover
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.borderL2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: tint),
              const SizedBox(width: 5),
              // Ellipsized rather than allowed its natural width: splitting a
              // 300px column gives panes around 140px, and three actions that
              // insist on their full labels overflow one.
              Flexible(
                child: Text(
                  widget.label,
                  style: DswType.xxs12.copyWith(color: tint),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A persisted tab whose type this build has no descriptor for — an older or
/// newer layout file. Shown rather than dropped, so closing it is the user's call.
class _Unknown extends StatelessWidget {
  const _Unknown({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          context.tr('unknownTabType', {'type': type}),
          textAlign: TextAlign.center,
          style: DswType.xs13.copyWith(color: color.labelTertiary),
        ),
      ),
    );
  }
}
