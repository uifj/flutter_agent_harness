// The sidebar column: brand row, New Session, the session list, and the foot.
//
// Ported from `deepseek-harness/packages/client/ui-sidebar/src/client/SidebarRoot.tsx`
// and its module CSS, including the two-phase collapse: the wide content fades
// out in place over 150ms at its frozen width (so the sliding column clips it
// rather than reflowing it), and only then does the 56px rail layout apply.
//
// Icon glyphs are the one deliberate divergence. dsh ships its own set
// (`FishLogo`, `IconNewChatOutline16`, `IconPanelLeftOutline16`); this build uses
// the nearest Material equivalents at the same sizes rather than inventing
// artwork.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../model/conversation.dart';
import '../../state/session_index.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../layout/columns.dart';

/// Wide-content unmount delay; matches the 150ms wide-content fade-out.
const _collapseSettle = Duration(milliseconds: 150);

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.collapsed,
    required this.width,
    required this.sessions,
    required this.onNewSession,
    required this.onToggle,
    required this.onOpenSession,
    required this.onOpenSettings,
    required this.onToggleDetails,
    required this.detailsOpen,
    required this.onToggleWorkbench,
    required this.workbenchOpen,
    required this.onToggleBottom,
    required this.bottomOpen,
  });

  /// The resolved rail state, decided by the frame's concession solve.
  final bool collapsed;

  /// The resolved column width, used to freeze the wide layout mid-collapse.
  final double width;

  final SessionIndex sessions;
  final VoidCallback onNewSession;
  final VoidCallback onToggle;
  final void Function(String id) onOpenSession;
  final VoidCallback onOpenSettings;

  /// Toggles the right-hand details column. Without this affordance the column
  /// could only be opened by clicking a tool call in the transcript — there was
  /// no way to reach the workbench before the first turn.
  final VoidCallback onToggleDetails;

  /// Whether the details column is currently open, so the toggle can show the
  /// active state. Fed from the frame's rebuild on [LayoutController].
  final bool detailsOpen;

  /// Toggles the workbench column — better-sidebar's panel-right button.
  final VoidCallback onToggleWorkbench;

  /// Whether the workbench column is currently open.
  final bool workbenchOpen;

  /// Toggles the bottom panel row — better-sidebar's panel-bottom button.
  final VoidCallback onToggleBottom;

  /// Whether the bottom row is currently open.
  final bool bottomOpen;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  /// True once the collapse fade has finished and the rail layout may apply.
  bool _settled = false;
  Timer? _settleTimer;

  /// The last width the column had while expanded, held so the fading content
  /// keeps its expanded layout instead of reflowing into the rail.
  double _lastWideWidth = sidebarDefault;

  @override
  void initState() {
    super.initState();
    _settled = widget.collapsed;
  }

  @override
  void didUpdateWidget(Sidebar old) {
    super.didUpdateWidget(old);
    if (widget.collapsed == old.collapsed) return;
    _settleTimer?.cancel();
    if (!widget.collapsed) {
      setState(() => _settled = false);
      return;
    }
    _settleTimer = Timer(_collapseSettle, () {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final wide = !widget.collapsed || !_settled;
    if (!widget.collapsed) _lastWideWidth = widget.width;

    final width = wide
        ? (widget.collapsed ? _lastWideWidth : widget.width)
        : sidebarCollapsed;

    return AnimatedOpacity(
      // Phase 1 of the collapse: everything fades out at its frozen width.
      opacity: widget.collapsed && wide ? 0 : 1,
      duration: DswMotion.respecting(context, _collapseSettle),
      curve: DswMotion.easeInOut,
      child: OverflowBox(
        alignment: AlignmentDirectional.topStart,
        // Phase 1 needs to be wider than the column it sits in: the frame lays this
        // out at the *target* width, which is already the rail, while the fading
        // content is still on the expanded layout. Releasing both bounds lets it
        // keep that width and be clipped by the column instead of reflowing into
        // the rail halfway through the fade.
        minWidth: 0,
        maxWidth: double.infinity,
        child: SizedBox(
          width: width,
          child: Padding(
            // Rail geometry: 36x36 controls centred in the 56px rail (10px sides),
            // 18px from the rail top to the first control.
            padding: wide
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                : const EdgeInsets.fromLTRB(10, 18, 10, 6),
            child: Column(
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                _logoRow(color, wide: wide),
                _newSessionButton(color, wide: wide),
                Expanded(child: _sessionList(color, wide: wide)),
                _footer(color, wide: wide),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 60px expanded, 36px on the rail. Expanded, the brand doubles as a New
  /// Session shortcut and the toggle sits at the right edge.
  Widget _logoRow(DswAlias color, {required bool wide}) => SizedBox(
    height: wide ? 60 : 36,
    child: Padding(
      padding: wide
          ? const EdgeInsets.only(left: 4, top: 8, bottom: 8)
          : EdgeInsets.zero,
      child: Row(
        mainAxisAlignment: wide
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.start,
        children: [
          if (wide)
            Expanded(
              child: _Pressable(
                onTap: widget.onNewSession,
                child: Row(
                  children: [
                    Icon(LucideIcons.droplet, size: 24, color: color.labelPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'DSH',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        // 18px/24px, weight 600, letter-spacing 0.04em — the one
                        // place dsh sets type outside the token scale.
                        style: DswType.l20.copyWith(
                          fontSize: 18,
                          height: 24 / 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 18 * 0.04,
                          color: color.labelPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          _IconButton(
            onTap: widget.onToggle,
            wide: wide,
            tooltip: widget.collapsed ? 'Open sidebar' : 'Collapse sidebar',
            // On the rail the toggle rests as the brand mark and reveals the
            // panel icon on hover — that swap *is* the expand affordance.
            builder: (hovered) => wide || hovered
                ? Icon(
                    LucideIcons.panel_right,
                    size: wide ? 16 : 18,
                    color: wide ? color.labelSecondary : color.labelPrimary,
                  )
                : Icon(LucideIcons.droplet, size: 24, color: color.labelPrimary),
          ),
        ],
      ),
    ),
  );

  /// A 38px bar with a 12px radius expanded; a plain rail control collapsed.
  Widget _newSessionButton(DswAlias color, {required bool wide}) => Padding(
    padding: wide
        ? const EdgeInsets.fromLTRB(2, 0, 2, 8)
        : const EdgeInsets.only(bottom: 12),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: _Pressable(
        onTap: widget.onNewSession,
        hoverColor: wide
            ? color.buttonFloatingHover
            : color.interactiveBgHover,
        borderRadius: BorderRadius.circular(wide ? 12 : 999),
        // Deliberately not animated. The two forms differ in width, and the wide
        // one hugs its label, so the pair is a finite width against an unbounded
        // one — `AnimatedContainer` lerps its constraints and cannot interpolate
        // across that, and the frames it spent trying were also feeding the row a
        // half-way width it could not fit its label into. Nothing is lost: the
        // label mounts and unmounts in the same frame regardless, and the visible
        // transition is the column's own fade in `build`.
        child: Container(
          width: wide ? null : 36,
          height: wide ? 38 : 36,
          padding: wide
              ? const EdgeInsets.symmetric(horizontal: 16)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: wide ? color.buttonElevatedFill : Colors.transparent,
            border: wide ? Border.all(color: color.borderL2) : null,
            borderRadius: BorderRadius.circular(wide ? 12 : 999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.message_square_plus,
                size: wide ? 14 : 18,
                color: color.labelPrimary,
              ),
              if (wide) ...[
                const SizedBox(width: 6),
                Text(
                  'New Session',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DswType.sStrong14.copyWith(color: color.labelPrimary),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  /// The browsing region. On the rail it degrades to an icon that asks for the
  /// column back, since 36px cannot hold a session title.
  Widget _sessionList(DswAlias color, {required bool wide}) {
    if (!wide) {
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: _IconButton(
          onTap: widget.onToggle,
          wide: false,
          tooltip: 'Sessions',
          builder: (_) => Icon(
            LucideIcons.message_square,
            size: 18,
            color: color.labelPrimary,
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: widget.sessions,
      builder: (context, _) {
        final sessions = widget.sessions.sessions;
        if (sessions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              widget.sessions.isLoading ? 'Loading…' : 'No sessions yet',
              style: DswType.xxs12.copyWith(color: color.labelTertiary),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: sessions.length,
          itemBuilder: (context, index) => _SessionRow(
            session: sessions[index],
            selected: sessions[index].id == widget.sessions.activeId,
            onTap: () => widget.onOpenSession(sessions[index].id),
          ),
        );
      },
    );
  }

  Widget _footer(DswAlias color, {required bool wide}) => Align(
    alignment: wide
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.center,
    child: wide
        ? Row(
            children: [
              Expanded(
                child: _Pressable(
                  onTap: widget.onOpenSettings,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Icon(
                          LucideIcons.settings,
                          size: 16,
                          color: color.labelSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Settings',
                          style: DswType.s14.copyWith(
                            color: color.labelPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _detailsToggle(color, wide: true),
              _workbenchToggle(color, wide: true),
              _bottomToggle(color, wide: true),
            ],
          )
        : Column(
            children: [
              _IconButton(
                onTap: widget.onOpenSettings,
                wide: false,
                tooltip: 'Settings',
                builder: (_) => Icon(
                  LucideIcons.settings,
                  size: 18,
                  color: color.labelPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _detailsToggle(color, wide: false),
              _workbenchToggle(color, wide: false),
              _bottomToggle(color, wide: false),
            ],
          ),
  );

  /// The right-column switch: the panel-right mirror of the header's
  /// panel-left toggle. Active tint while the column is open.
  Widget _detailsToggle(DswAlias color, {required bool wide}) => _IconButton(
    onTap: widget.onToggleDetails,
    wide: wide,
    tooltip: widget.detailsOpen ? 'Close details panel' : 'Open details panel',
    builder: (_) => Transform.flip(
      flipX: true,
      child: Icon(
        LucideIcons.panel_right,
        size: wide ? 16 : 18,
        color: widget.detailsOpen ? color.labelPrimary : color.labelSecondary,
      ),
    ),
  );

  /// The workbench column's switch — better-sidebar's `IconPanelRightOutline16`.
  Widget _workbenchToggle(DswAlias color, {required bool wide}) => _IconButton(
    onTap: widget.onToggleWorkbench,
    wide: wide,
    tooltip: widget.workbenchOpen
        ? 'Close workbench panel'
        : 'Open workbench panel',
    builder: (_) => Icon(
      LucideIcons.panel_right,
      size: wide ? 16 : 18,
      color: widget.workbenchOpen
          ? color.labelPrimary
          : color.labelSecondary,
    ),
  );

  /// The bottom panel row's switch — better-sidebar's
  /// `IconPanelBottomOutline16`.
  Widget _bottomToggle(DswAlias color, {required bool wide}) => _IconButton(
    onTap: widget.onToggleBottom,
    wide: wide,
    tooltip: widget.bottomOpen ? 'Close bottom panel' : 'Open bottom panel',
    builder: (_) => Icon(
      LucideIcons.panel_bottom,
      size: wide ? 16 : 18,
      color: widget.bottomOpen ? color.labelPrimary : color.labelSecondary,
    ),
  );
}

/// A 32px session row: 8px padding, radius 8, hover and selected share the same
/// wash (`Rows.module.css:7-25, 108-118`).
class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.selected,
    required this.onTap,
  });

  final SessionSummary session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    return _Pressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.interactiveBgHover : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                session.title ?? 'Untitled',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.s14.copyWith(
                  height: 20 / 14,
                  color: color.labelPrimary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _time(session.updatedAt),
              style: DswType.xxs12.copyWith(
                height: 20 / 12,
                color: color.labelTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Today shows a clock, anything older a date — the row has 12px of type to
  /// spend and the day is the part that stops being useful first.
  static String _time(DateTime at) {
    final now = DateTime.now();
    final local = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${two(local.hour)}:${two(local.minute)}';
    }
    return '${two(local.month)}/${two(local.day)}';
  }
}

/// A hover-washed tap target. Material's `InkWell` would bring a ripple and its
/// own hover colour; dsh washes the whole row with an alias token instead.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.child,
    this.hoverColor,
    this.borderRadius,
  });

  final VoidCallback onTap;
  final Widget child;

  /// Null means no wash at all — the brand row is a button in behaviour only.
  final Color? hoverColor;
  final BorderRadius? borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final wash = widget.hoverColor ?? context.dsw.interactiveBgHover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _hovered ? wash : null,
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// A round icon control: 28px expanded, 36px on the rail. The builder receives
/// the hover state, which the rail toggle needs in order to swap its glyph.
class _IconButton extends StatefulWidget {
  const _IconButton({
    required this.onTap,
    required this.wide,
    required this.tooltip,
    required this.builder,
  });

  final VoidCallback onTap;
  final bool wide;
  final String tooltip;
  final Widget Function(bool hovered) builder;

  @override
  State<_IconButton> createState() => _IconButtonState();
}

class _IconButtonState extends State<_IconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final size = widget.wide ? 28.0 : 36.0;
    // The rail toggle rests as the brand mark with no hover circle, matching
    // `.collapsed .toggle`; every other state gets the wash.
    final washed = _hovered;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: washed ? context.dsw.interactiveBgHover : null,
            ),
            child: Center(child: widget.builder(_hovered)),
          ),
        ),
      ),
    );
  }
}
