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

import '../../l10n/locales.dart';
import '../../model/app_settings.dart' as appcfg;
import '../../model/conversation.dart';
import '../../model/user_profile.dart';
import '../../state/hotkey_service.dart';
import '../../state/session_index.dart';
import '../../state/workspace_mode_controller.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/tappable.dart';
import '../settings/widgets/settings_quick_menu.dart';
import '../layout/columns.dart';

/// Wide-content unmount delay; matches the 150ms wide-content fade-out.
const _collapseSettle = Duration(milliseconds: 150);

/// The New Session bar's round: a 12px card expanded, a full circle on the rail.
///
/// Spelled once because the hover wash and the fill draw the same round — two
/// copies of that decision is a seam where they can disagree.
BorderRadius _barRadius(bool wide) =>
    DswShape.radius(wide ? DswShape.shell : DswShape.pill);

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    required this.collapsed,
    required this.width,
    required this.sessions,
    this.profile,
    this.settings,
    this.onSettingsChanged,
    this.mode,
    this.onSelectMode,
    this.extensionView,
    this.onToggleExtension,
    required this.onNewSession,
    required this.onToggle,
    required this.onOpenSession,
    required this.onOpenSettings,
    required this.onToggleDetails,
    required this.detailsOpen,
  });

  /// The resolved rail state, decided by the frame's concession solve.
  final bool collapsed;

  /// The resolved column width, used to freeze the wide layout mid-collapse.
  final double width;

  final SessionIndex sessions;

  /// The signed-in user, or null while the profile source is loading or when
  /// there is none — the footer avatar then shows an anonymous placeholder.
  final UserProfile? profile;

  /// The settings document the footer quick-menu edits, and the live-save path.
  /// Both null (menu disabled) in tests that build a bare Sidebar.
  final appcfg.AppSettings? settings;
  final ValueChanged<appcfg.AppSettings>? onSettingsChanged;

  /// The top-level workspace the app is in (ADR-0007), and the switch. Null
  /// (switch hidden) in tests that build a bare Sidebar.
  final WorkspaceMode? mode;
  final ValueChanged<WorkspaceMode>? onSelectMode;

  /// The plan workspace's open extension panel, and its toggle (ADR-0007 D4).
  /// Null (group hidden) when no mode switch is wired.
  final PlanExtensionView? extensionView;
  final ValueChanged<PlanExtensionView>? onToggleExtension;

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

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  /// True once the collapse fade has finished and the rail layout may apply.
  bool _settled = false;
  Timer? _settleTimer;

  /// Anchors the footer quick-menu to the profile row.
  final _menuLink = LayerLink();

  /// The open quick-menu's overlay entry, owned by this state (audit F2).
  OverlayEntry? _quickMenu;

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
    // The quick-menu overlay entry is owned here (audit F2): the sidebar going
    // away — a body swap to the full settings view, most commonly — must take
    // its popup with it, or the menu floats over the new surface.
    if (_quickMenu != null && _quickMenu!.mounted) _quickMenu!.remove();
    _quickMenu = null;
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
                ? const EdgeInsets.symmetric(
                    horizontal: DswShape.sidebarInset,
                    vertical: DswShape.sm,
                  )
                : const EdgeInsets.fromLTRB(10, 18, 10, 8),
            child: Column(
              crossAxisAlignment: wide
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.center,
              children: [
                // Expanded, the column reads as one scroll view: measured in a
                // 600px window in 企划 mode, the growing chrome (brand row, mode
                // switch, three extension rows, New Session) left the session
                // list 77.8px at the 1.8x text step and 0.0px at 2.2x - the
                // sessions were unreachable while the chrome they sat behind
                // stayed on screen. Chrome may scroll away, content may not
                // vanish. The rail has no chrome to spare and its list is a
                // single glyph, so it keeps the plain column.
                if (wide)
                  Expanded(
                    child: ListenableBuilder(
                      listenable: widget.sessions,
                      builder: (context, _) => CustomScrollView(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _chrome(color, wide: true),
                            ),
                          ),
                          ..._sessionSlivers(color),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ..._chrome(color, wide: false),
                  Expanded(child: _sessionList(color)),
                ],
                _footer(color, wide: wide),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The column's chrome: the brand row, the workspace switch with its
  /// extension rows, and New Session. A list rather than a widget because the
  /// wide form lays it out inside a sliver and the rail lays it out directly.
  List<Widget> _chrome(DswAlias color, {required bool wide}) => [
    _logoRow(color, wide: wide),
    if (widget.onSelectMode != null) ...[
      SizedBox(height: wide ? DswShape.md : DswShape.xs),
      _modeSwitch(color, wide: wide),
      // The plan workspace's extension panels (ADR-0007 D4) — starkins's
      // `_ExtensionGroup` shape: visible only in 企划, each row its own toggle.
      if (widget.mode == WorkspaceMode.plan) ...[
        const SizedBox(height: DswShape.sm),
        _extensionGroup(color, wide: wide),
      ],
    ],
    _newSessionButton(color, wide: wide),
  ];

  /// The top-level workspace switch (ADR-0007), starkins's `_TaskChannelTabs`
  /// shape in dsw tokens: a two-cell segmented control expanded, and on the
  /// rail a single toggle that flips to the OTHER workspace — the one control
  /// a 36px rail can afford, and its icon names where the tap lands.
  Widget _modeSwitch(DswAlias color, {required bool wide}) {
    final onSelect = widget.onSelectMode!;
    final mode = widget.mode ?? WorkspaceMode.agent;
    // One line of chrome, so both seats ride the text step: a nailed 32/28 held
    // 40.0 worth of s14 label at the system's 1.8x step and cut "Plan"/"Agent".
    final step = MediaQuery.textScalerOf(context).scale(1);
    if (!wide) {
      final other = mode == WorkspaceMode.agent
          ? WorkspaceMode.plan
          : WorkspaceMode.agent;
      return _IconButton(
        onTap: () => onSelect(other),
        wide: false,
        tooltip: other == WorkspaceMode.plan
            ? context.tr('planMode')
            : context.tr('agentMode'),
        builder: (_) => Icon(
          mode == WorkspaceMode.agent
              ? LucideIcons.book_open
              : LucideIcons.message_square,
          size: DswShape.iconLg,
          color: color.labelPrimary,
        ),
      );
    }
    return Container(
      height: 32 * step,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.bgLayer3,
        borderRadius: BorderRadius.circular(DswShape.card),
      ),
      child: Row(
        children: [
          for (final (candidate, icon, label) in [
            (WorkspaceMode.plan, LucideIcons.book_open, context.tr('planMode')),
            (
              WorkspaceMode.agent,
              LucideIcons.message_square,
              context.tr('agentMode'),
            ),
          ])
            Expanded(
              child: LayoutBuilder(
                builder: (context, cell) {
                  // The composer chips' rule, applied to the switch: a cell that
                  // cannot fit its label sheds the label before the row gives up
                  // on the control. 71px is 'Agent' at s14 - the wider of the two
                  // names in English (the 企划 pair is shorter) - and the glyph
                  // plus its gap cost 20. At the system's 1.8x step the label
                  // wanted 127.2 in a 126.0 cell and spilled, which is what this
                  // line replaces; the glyph alone still says which mode is which.
                  final showLabel = cell.maxWidth >= 20 + 71 * step;
                  return _Pressable(
                    onTap: () => onSelect(candidate),
                    hoverColor: color.sidebarNavItemActive,
                    borderRadius: BorderRadius.circular(DswShape.control),
                    semanticLabel: showLabel ? null : label,
                    child: Container(
                      height: 28 * step,
                      decoration: BoxDecoration(
                        color: mode == candidate
                            ? color.sidebarNavItemActive
                            : null,
                        borderRadius: BorderRadius.circular(DswShape.control),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: DswShape.iconSm,
                            color: mode == candidate
                                ? color.labelPrimary
                                : color.labelSecondary,
                          ),
                          if (showLabel) ...[
                            const SizedBox(width: 6),
                            // Flexible, not a bare Text: a Row hands a non-flex
                            // child the whole row width to size itself in, so the
                            // ellipsis would never have triggered.
                            Flexible(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DswType.s14.copyWith(
                                  color: mode == candidate
                                      ? color.labelPrimary
                                      : color.labelSecondary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// The plan workspace's extension panels (ADR-0007 D4) — starkins's
  /// `_ExtensionGroup`: a labelled group of rows, each a toggle for one panel
  /// (board / calendar / table). Only shown in 企划 mode with a wired toggle.
  Widget _extensionGroup(DswAlias color, {required bool wide}) {
    final onToggle = widget.onToggleExtension;
    if (onToggle == null) return const SizedBox.shrink();
    final open = widget.extensionView ?? PlanExtensionView.none;
    // Only the expanded row carries a label, so only its seat rides the step:
    // a nailed 32 cut 'Board'/'Calendar'/'Table' at 40.0 wanted, 1.8x's measure.
    final step = MediaQuery.textScalerOf(context).scale(1);
    final entries = [
      (PlanExtensionView.board, LucideIcons.kanban, context.tr('planBoard')),
      (
        PlanExtensionView.calendar,
        LucideIcons.calendar,
        context.tr('planCalendar'),
      ),
      (PlanExtensionView.table, LucideIcons.table, context.tr('planTable')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              context.tr('planExtensions'),
              style: DswType.xxxs11.copyWith(color: color.labelTertiary),
            ),
          ),
        for (final (view, icon, label) in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _Pressable(
              onTap: () => onToggle(view),
              borderRadius: BorderRadius.circular(DswShape.control),
              child: Container(
                height: wide ? 32 * step : 36,
                padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 0),
                decoration: BoxDecoration(
                  color: open == view ? color.interactiveBgHover : null,
                  borderRadius: BorderRadius.circular(DswShape.control),
                ),
                child: Row(
                  mainAxisAlignment: wide
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: wide ? 15 : 18,
                      color: open == view
                          ? color.labelPrimary
                          : color.labelSecondary,
                    ),
                    if (wide) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DswType.s14.copyWith(
                            color: open == view
                                ? color.labelPrimary
                                : color.labelSecondary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 60px expanded, 36px on the rail. Expanded, the brand doubles as a New
  /// Session shortcut and the toggle sits at the right edge.
  ///
  /// No horizontal inset of its own: the column already pads by
  /// [DswShape.sidebarInset], and adding a second offset here is what put the
  /// logo four pixels off the line every row below it starts on.
  Widget _logoRow(DswAlias color, {required bool wide}) => SizedBox(
    height: wide ? 60 : 36,
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
                  Icon(
                    LucideIcons.droplet,
                    size: 24,
                    color: color.labelPrimary,
                  ),
                  const SizedBox(width: DswShape.sm),
                  Flexible(
                    child: Text(
                      context.tr('appName'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      // 18px/24px, weight 600, letter-spacing 0.04em — the one
                      // place dsh sets type outside the token scale.
                      style: DswType.brand18.copyWith(
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
          // The accelerator is spelled by whoever registers it, so the tooltip
          // and the key cannot drift apart.
          tooltip: context.tr(
            widget.collapsed ? 'openSidebar' : 'collapseSidebar',
            {'accel': HotkeyService.sidebarAccelerator},
          ),
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
  );

  /// A 38px bar with a 12px radius expanded; a plain rail control collapsed.
  Widget _newSessionButton(DswAlias color, {required bool wide}) => Padding(
    // No side inset: this bar sits between the mode switch and the session
    // list, both of which fill the column, and being 4px narrower than the
    // two controls it is stacked between is what read as "misaligned".
    padding: const EdgeInsets.only(bottom: DswShape.md),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: _Pressable(
        onTap: widget.onNewSession,
        // The rail's form sheds the words, so it has to keep the name: without
        // this the only thing a screen reader got was an unlabelled button.
        semanticLabel: wide ? null : context.tr('newSession'),
        hoverColor: wide ? color.buttonFloatingHover : color.interactiveBgHover,
        borderRadius: _barRadius(wide),
        // Deliberately not animated. The two forms differ in width, and the wide
        // one hugs its label, so the pair is a finite width against an unbounded
        // one — `AnimatedContainer` lerps its constraints and cannot interpolate
        // across that, and the frames it spent trying were also feeding the row a
        // half-way width it could not fit its label into. Nothing is lost: the
        // label mounts and unmounts in the same frame regardless, and the visible
        // transition is the column's own fade in `build`.
        child: Container(
          width: wide ? null : 36,
          // One line of chrome, so the seat rides the text step instead of
          // clipping it: a nailed 36 held 40 worth of 14/22 label at the system's
          // 1.8x step. The bar is the same 36 at the designed step.
          height:
              DswShape.rowSession * MediaQuery.textScalerOf(context).scale(1),
          padding: wide
              ? const EdgeInsets.symmetric(horizontal: 16)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: wide ? color.buttonElevatedFill : Colors.transparent,
            border: wide ? Border.all(color: color.borderL2) : null,
            borderRadius: _barRadius(wide),
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
                // Flexible, not a bare ellipsised Text: a Row measures its
                // non-flex children against an unbounded width, so the ellipsis
                // alone never gets to trigger. At the system's 1.8x text step
                // this label wanted 299.9px in a 222px bar and spilled 78px.
                Flexible(
                  child: Text(
                    context.tr('newSession'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DswType.sStrong14.copyWith(
                      color: color.labelPrimary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  /// The rail's browsing region: an icon that asks for the column back, since
  /// 36px cannot hold a session title. The wide column's own list is a sliver
  /// ([_sessionSlivers]), because its chrome scrolls with it.
  Widget _sessionList(DswAlias color) => Align(
    alignment: AlignmentDirectional.topStart,
    child: _IconButton(
      onTap: widget.onToggle,
      wide: false,
      tooltip: context.tr('sessions'),
      builder: (_) => Icon(
        LucideIcons.message_square,
        size: DswShape.iconLg,
        color: color.labelPrimary,
      ),
    ),
  );

  /// The sessions, as slivers to sit under the column's chrome in one scroll
  /// view. Called from inside a `ListenableBuilder` on the index, so the list
  /// stays lazy: the builder only runs for rows the viewport reaches.
  List<Widget> _sessionSlivers(DswAlias color) {
    final sessions = widget.sessions.sessions;
    if (sessions.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              widget.sessions.isLoading
                  ? context.tr('loading')
                  : context.tr('noSessionsYet'),
              style: DswType.xxs12.copyWith(color: color.labelTertiary),
            ),
          ),
        ),
      ];
    }
    return [
      SliverList.builder(
        itemCount: sessions.length,
        itemBuilder: (context, index) => _SessionRow(
          session: sessions[index],
          selected: sessions[index].id == widget.sessions.activeId,
          onTap: () => widget.onOpenSession(sessions[index].id),
        ),
      ),
    ];
  }

  Widget _footer(DswAlias color, {required bool wide}) => Align(
    alignment: wide
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.center,
    child: wide
        ? _footerWide(color)
        : Column(
            children: [
              // The rail avatar is the same quick-menu trigger as the wide
              // profile row (audit F5) — collapsing the sidebar must not take
              // the menu away.
              CompositedTransformTarget(
                link: _menuLink,
                child: DswHoverTap(
                  onTap: _canMenu ? _openQuickMenu : null,
                  semanticLabel: context.tr('quickPreferences'),
                  builder: (context, hovered, _) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hovered && _canMenu
                          ? color.interactiveBgHover
                          : null,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: _UserAvatar(
                      profile: widget.profile,
                      color: color,
                      size: 32,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _IconButton(
                onTap: _openSettingsSafe,
                wide: false,
                tooltip: context.tr('settings'),
                builder: (_) => Icon(
                  LucideIcons.settings,
                  size: DswShape.iconLg,
                  color: color.labelPrimary,
                ),
              ),
              const SizedBox(height: 4),
              _detailsToggle(color, wide: false),
            ],
          ),
  );

  /// Wide footer: the profile row is the quick-menu trigger, and the gear and
  /// the panel toggle are targets of their own.
  ///
  /// The two controls used to sit *inside* the trigger, which is what made the
  /// gear read as orphaned (audit 2c ③): hovering it lit the whole row up, a tap
  /// in the empty middle opened the menu, and the semantics tree showed one
  /// button containing two. Grouping them by nesting was the wrong grouping —
  /// they share a baseline and a 4px gap, not a hit area.
  Widget _footerWide(DswAlias color) {
    final profile = widget.profile;
    final canMenu = _canMenu;
    return Row(
      children: [
        Expanded(
          child: CompositedTransformTarget(
            link: _menuLink,
            child: DswHoverTap(
              onTap: canMenu ? _openQuickMenu : null,
              semanticLabel: context.tr('quickPreferences'),
              builder: (context, hovered, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: hovered && canMenu ? color.interactiveBgHover : null,
                  borderRadius: BorderRadius.circular(DswShape.control),
                ),
                child: Row(
                  children: [
                    _UserAvatar(profile: profile, color: color),
                    const SizedBox(width: 8),
                    if (profile != null)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DswType.s14.copyWith(
                                color: color.labelPrimary,
                              ),
                            ),
                            Text(
                              profile.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DswType.xxs12.copyWith(
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
        _Pressable(
          onTap: _openSettingsSafe,
          // Same gap in the wide footer's gear — icon-only, no label, no
          // tooltip, so the audit could only name it by codepoint.
          semanticLabel: context.tr('settings'),
          borderRadius: BorderRadius.circular(DswShape.control),
          child: Container(
            height: 28,
            width: 28,
            alignment: Alignment.center,
            child: Icon(
              LucideIcons.settings,
              size: DswShape.iconMd,
              color: color.labelSecondary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _detailsToggle(color, wide: true),
      ],
    );
  }

  /// Whether the quick-menu has everything it needs: a document and a save
  /// path. False in tests that build a bare Sidebar — the trigger rests inert.
  bool get _canMenu =>
      widget.settings != null && widget.onSettingsChanged != null;

  /// Opens (or re-opens) the footer quick-menu, owning its overlay entry
  /// (audit F2): an existing entry is removed first, so the menu can never
  /// stack on itself.
  void _openQuickMenu() {
    if (!_canMenu) return;
    if (_quickMenu != null && _quickMenu!.mounted) _quickMenu!.remove();
    _quickMenu = showSettingsQuickMenu(
      context: context,
      link: _menuLink,
      initial: widget.settings!,
      onChanged: widget.onSettingsChanged!,
      onOpenSettings: _openSettingsSafe,
    );
  }

  /// Opens the full settings view, closing the quick-menu first — the body
  /// swap unmounts this sidebar, and a leftover entry would float over the new
  /// surface (audit F2).
  void _openSettingsSafe() {
    if (_quickMenu != null && _quickMenu!.mounted) _quickMenu!.remove();
    _quickMenu = null;
    widget.onOpenSettings();
  }

  /// The right-column switch: the panel-right mirror of the header's
  /// panel-left toggle. Active tint while the column is open.
  ///
  /// The workbench and bottom panels' toggles live at the viewport's top-right
  /// corner, not here — better-sidebar pins them beside the panels they switch,
  /// and a footer copy would be a second answer to the same question.
  Widget _detailsToggle(DswAlias color, {required bool wide}) => _IconButton(
    onTap: widget.onToggleDetails,
    wide: wide,
    tooltip: widget.detailsOpen
        ? context.tr('closeDetailsPanel')
        : context.tr('openDetailsPanel'),
    builder: (_) => Transform.flip(
      flipX: true,
      child: Icon(
        LucideIcons.panel_right,
        size: wide ? 16 : 18,
        color: widget.detailsOpen ? color.labelPrimary : color.labelSecondary,
      ),
    ),
  );
}

/// A 36px session row: 10px padding, radius 8, hover and selected share the same
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
    final title = session.title ?? context.tr('untitled');
    // A one-line seat rides the text step (ADR-0017 S3). Pinned at 36 this row is
    // exactly one line at 1.8x and one clipped line at the next step up: at 2.2x
    // both the title and the time label wanted 44.0 of the 36.0 they were handed.
    final step = MediaQuery.textScalerOf(context).scale(1);
    return Tooltip(
      // The row ellipsises, and the column is 280px wide by default: after the
      // time label there is roughly 200px for the title, so most real titles are
      // cut. Truncation is the right strategy (audit 2a) - it just has to leave a
      // way to read the rest, which on a desktop means on hover.
      message: title,
      child: Semantics(
        // The other half of "which session is up", for a screen reader and for
        // anyone who cannot tell a 10% wash from a 6% one. `container` because
        // the row's button flag and its focus action live on nodes below: without
        // a merge boundary the flag landed where nothing is handed it, and the row
        // still announced as an ordinary button.
        selected: selected,
        container: true,
        child: _Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(DswShape.control),
          child: Container(
            height: DswShape.rowSession * step,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected ? color.interactiveSelected : null,
              borderRadius: BorderRadius.circular(DswShape.control),
            ),
            child: Row(
              children: [
                // The row-head slot, and the second half of audit 2b. It is the
                // width of the neighbours' icons (14) plus their gap (6), so a
                // title starts on the same line a mode label does - and it is
                // reserved on EVERY row: a dot that only the selected row has
                // would shove that row's text sideways, which is a jump, not an
                // indicator. No left accent bar: the audit corrected that to
                // ZCode's slot + distinct token.
                SizedBox(
                  width: 14,
                  child: selected
                      ? Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color.brandPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const SizedBox.square(dimension: 6),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
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
    this.semanticLabel,
  });

  final VoidCallback onTap;
  final Widget child;

  /// Names the control when nothing in [child] can: the mode cell sheds its
  /// label once the text step makes it too wide, and a lone glyph is unnamed.
  final String? semanticLabel;

  /// Null means no wash at all — the brand row is a button in behaviour only.
  final Color? hoverColor;
  final BorderRadius? borderRadius;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  @override
  Widget build(BuildContext context) {
    final wash = widget.hoverColor ?? context.dsw.interactiveBgHover;
    return DswHoverTap(
      onTap: widget.onTap,
      semanticLabel: widget.semanticLabel,
      builder: (context, hovered, _) => AnimatedContainer(
        duration: DswMotion.respecting(context, DswMotion.fast),
        decoration: BoxDecoration(
          color: hovered ? wash : null,
          borderRadius: widget.borderRadius,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A round icon control: 28px expanded, 36px on the rail. The builder receives
/// the hover state, which the rail toggle needs in order to swap its glyph.
class _IconButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final size = wide ? 28.0 : 36.0;
    return Tooltip(
      message: tooltip,
      child: DswHoverTap(
        onTap: onTap,
        // The tooltip is the button's name; the glyph inside says nothing to a
        // screen reader, so exclude it.
        semanticLabel: tooltip,
        excludeSemantics: true,
        builder: (context, hovered, _) => AnimatedContainer(
          duration: DswMotion.respecting(context, DswMotion.fast),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hovered ? context.dsw.interactiveBgHover : null,
          ),
          child: Center(child: builder(hovered)),
        ),
      ),
    );
  }
}

/// The footer identity avatar: a filled circle carrying the profile's initial,
/// coloured from a dsw palette by `avatarColorIndex`. With no profile (loading
/// or signed out) it rests as a muted user glyph — a placeholder, never a fake
/// identity.
class _UserAvatar extends StatelessWidget {
  const _UserAvatar({
    required this.profile,
    required this.color,
    this.size = 28,
  });

  final UserProfile? profile;
  final DswAlias color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return MediaQuery.withNoTextScaling(
      // The initial is decoration, not content: the name is spelled out beside it
      // in the wide footer and the control's accessible name is the quick-menu
      // label. Grown with the step it wanted 36.0 inside a 28.0 circle (and the
      // rail has no room for a bigger one), so the glyph rides the circle rather
      // than the user's setting.
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: profile == null
              ? color.bgLayer3
              : _avatarFill(color, profile.avatarColorIndex),
        ),
        child: profile == null
            ? Icon(
                LucideIcons.user,
                size: size * 0.55,
                color: color.labelTertiary,
              )
            : Text(
                profile.initial,
                style: DswType.xsStrong13.copyWith(
                  color: color.labelPrimaryForeground,
                ),
              ),
      ),
    );
  }
}

/// The avatar palette — accent fills that all carry `labelPrimaryForeground`.
/// An index (from the profile) into a small fixed set, so the model can stay a
/// plain int rather than a `Color`.
Color _avatarFill(DswAlias c, int index) {
  final palette = [
    c.brandPrimary,
    c.stateBusinessPrimary,
    c.buttonInfoFill,
    c.stateSuccessPrimary,
  ];
  return palette[index % palette.length];
}
