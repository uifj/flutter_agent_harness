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
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadButton, ShadDialog, ShadInput, showShadDialog;

import '../../host/reveal.dart';
import '../../l10n/locales.dart';
import '../../model/app_settings.dart' as appcfg;
import '../../model/conversation.dart';
import '../../model/relative_time.dart';
import '../../model/session_groups.dart';
import '../../model/user_profile.dart';
import '../../model/workbench_prefs.dart';
import '../../state/hotkey_service.dart';
import '../../state/session_index.dart';
import '../../state/workspace_mode_controller.dart';
import '../../theme/dsw_alias.dart';
import '../../theme/dsw_motion.dart';
import '../../theme/dsw_shape.dart';
import '../../theme/dsw_theme.dart';
import '../../theme/dsw_typography.dart';
import '../primitives/confirm_dialog.dart';
import '../primitives/feedback.dart';
import '../primitives/icon_button.dart';
import '../primitives/menu.dart';
import '../primitives/segmented.dart';
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
    this.collections = const [],
    this.openCollectionId,
    this.onOpenCollection,
    this.onAddCollection,
    this.onOpenLibrary,
    this.extensionView,
    required this.onNewSession,
    required this.onToggle,
    required this.onOpenSession,
    required this.onOpenSettings,
    required this.onToggleDetails,
    required this.detailsOpen,
    this.currentWorkspace,
    this.knownWorkspaces = const [],
    this.historyOrganize = HistoryOrganize.project,
    this.collapsedWorkspaces = const {},
    this.onToggleWorkspaceCollapsed,
    this.onHistoryOrganizeChanged,
    this.onNewSessionInWorkspace,
    this.onRemoveWorkspace,
    this.onOpenWorkspaceTree,
    this.onAddWorkspace,
    this.onSetCollapsedWorkspaces,
  });

  /// The resolved rail state, decided by the frame's concession solve.
  final bool collapsed;

  /// The resolved column width, used to freeze the wide layout mid-collapse.
  final double width;

  final SessionIndex sessions;

  /// The folder the app is working in right now, and every folder the history
  /// or the settings know about. Both feed the grouped history (ADR-0039): the
  /// first decides which group leads, the second decides which folders appear
  /// at all when they hold no conversation yet.
  final String? currentWorkspace;
  final List<String> knownWorkspaces;

  /// The history's arrangement and the folded folders. View state owned by the
  /// prefs document, handed in rather than read from a provider (rule 6).
  final HistoryOrganize historyOrganize;
  final Set<String> collapsedWorkspaces;

  /// The five actions the grouped history can ask for. All optional: a bare
  /// `Sidebar` in a test has no workspace to switch to and no prefs to fold.
  final ValueChanged<String>? onToggleWorkspaceCollapsed;
  final ValueChanged<HistoryOrganize>? onHistoryOrganizeChanged;
  final ValueChanged<String>? onNewSessionInWorkspace;
  final ValueChanged<String>? onRemoveWorkspace;
  final ValueChanged<String>? onOpenWorkspaceTree;

  /// The section head's `+`: bring another folder into the list. Same picker as
  /// the hero's, because a second path to granting access is a second answer to
  /// "which folder may the agent read".
  final VoidCallback? onAddWorkspace;

  /// Replaces the whole fold set at once (expand all / collapse all). One write
  /// per gesture, so a collapse-all cannot leave the list half-folded if a
  /// notification lands in the middle.
  final ValueChanged<Set<String>>? onSetCollapsedWorkspaces;

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

  /// The plan collections the extension area lists (ADR-0037 P7, user
  /// decision 2026-10-01: the area answers "which collection is open", not
  /// three hard-coded panels). Empty (group hidden) when no mode switch is
  /// wired or the store has no collections.
  final List<({String id, String name})> collections;
  final String? openCollectionId;
  final void Function(String collectionId)? onOpenCollection;

  /// The plan pane currently showing (a collection's data view or one of the
  /// library screens), so the rows can carry the open state.
  final PlanExtensionView? extensionView;

  /// Opens the new-set/collection dialog (the extension group's "+").
  final VoidCallback? onAddCollection;

  /// Opens one of the parameterless library screens (All Content, widgets,
  /// bin, Gallery).
  final void Function(PlanExtensionView view)? onOpenLibrary;

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
                          // 企划 has no conversation module: the extension
                          // area (collections + library) takes the sessions'
                          // scroll body, and New Session disappears with
                          // them (user decision 2026-10-01).
                          if (widget.mode == WorkspaceMode.plan)
                            ..._librarySlivers(color)
                          else
                            ..._sessionSlivers(color),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ..._chrome(color, wide: false),
                  Expanded(
                    child: widget.mode == WorkspaceMode.plan
                        ? SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _libraryBody(color, wide: false),
                            ),
                          )
                        : _sessionList(color),
                  ),
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
    ],
    // The conversation module's affordance: agent-mode only.
    if (widget.mode != WorkspaceMode.plan) _newSessionButton(color, wide: wide),
  ];

  /// The top-level workspace switch (ADR-0007), starkins's `_TaskChannelTabs`
  /// shape in dsw tokens: a two-cell segmented control expanded, and on the
  /// rail a single toggle that flips to the OTHER workspace — the one control
  /// a 36px rail can afford, and its icon names where the tap lands.
  Widget _modeSwitch(DswAlias color, {required bool wide}) {
    final onSelect = widget.onSelectMode!;
    final mode = widget.mode ?? WorkspaceMode.agent;
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
    return DswSegmented<WorkspaceMode>(
      selected: mode,
      onSelect: onSelect,
      segments: [
        DswSegment(
          value: WorkspaceMode.plan,
          icon: LucideIcons.book_open,
          label: context.tr('planMode'),
        ),
        DswSegment(
          value: WorkspaceMode.agent,
          icon: LucideIcons.message_square,
          label: context.tr('agentMode'),
        ),
      ],
    );
  }

  /// The plan collections (ADR-0037; user decision 2026-10-01): a labelled
  /// group of rows, one per collection, each toggling its data view. Only
  /// shown in 企划 mode with a wired toggle.
  Widget _extensionGroup(DswAlias color, {required bool wide}) {
    final onOpen = widget.onOpenCollection;
    final collections = widget.collections;
    if (onOpen == null || collections.isEmpty) {
      return const SizedBox.shrink();
    }
    final openId = widget.openCollectionId;
    // Only the expanded row carries a label, so only its seat rides the step:
    // a nailed 32 cut labels at 40.0 wanted, 1.8x's measure.
    final step = MediaQuery.textScalerOf(context).scale(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (wide)
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 4, bottom: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('planCollections'),
                    style: DswType.xxxs11.copyWith(color: color.labelTertiary),
                  ),
                ),
                if (widget.onAddCollection != null)
                  Tooltip(
                    message: context.tr('planNewCollection'),
                    child: DswHoverTap(
                      onTap: widget.onAddCollection,
                      semanticLabel: context.tr('planNewCollection'),
                      builder: (context, hovered, focused) => Icon(
                        LucideIcons.plus,
                        size: DswShape.iconCaption,
                        color: color.labelTertiary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        for (final (index, collection) in collections.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _Pressable(
              onTap: () => onOpen(collection.id),
              borderRadius: BorderRadius.circular(DswShape.control),
              child: Container(
                height: wide ? 32 * step : 36,
                padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 0),
                decoration: BoxDecoration(
                  color: openId == collection.id
                      ? color.interactiveBgHover
                      : null,
                  borderRadius: BorderRadius.circular(DswShape.control),
                ),
                child: Row(
                  mainAxisAlignment: wide
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      index.isEven ? LucideIcons.kanban : LucideIcons.inbox,
                      size: wide ? 15 : 18,
                      color: openId == collection.id
                          ? color.labelPrimary
                          : color.labelSecondary,
                    ),
                    if (wide) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          collection.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DswType.s14.copyWith(
                            color: openId == collection.id
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

  /// The extension area's scroll body in 企划: the collections group (which
  /// carries its own "+") followed by the library group — the screens that
  /// are not one collection. Replaces the session list, which belongs to the
  /// 代理 conversation module.
  List<Widget> _librarySlivers(DswAlias color) => [
    SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _libraryBody(color, wide: true),
      ),
    ),
  ];

  List<Widget> _libraryBody(DswAlias color, {required bool wide}) {
    final onOpen = widget.onOpenLibrary;
    final openView = widget.extensionView;
    final step = MediaQuery.textScalerOf(context).scale(1);
    final groups = [
      _extensionGroup(color, wide: wide),
      if (onOpen != null) ...[
        const SizedBox(height: DswShape.sm),
        if (wide)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: Text(
              context.tr('planLibrary'),
              style: DswType.xxxs11.copyWith(color: color.labelTertiary),
            ),
          ),
        for (final view in PlanExtensionView.libraryScreens)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _Pressable(
              onTap: () => onOpen(view),
              borderRadius: BorderRadius.circular(DswShape.control),
              child: Container(
                height: wide ? 32 * step : 36,
                padding: EdgeInsets.symmetric(horizontal: wide ? 8 : 0),
                decoration: BoxDecoration(
                  color: openView == view ? color.interactiveBgHover : null,
                  borderRadius: BorderRadius.circular(DswShape.control),
                ),
                child: Row(
                  mainAxisAlignment: wide
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Icon(
                      switch (view) {
                        PlanExtensionView.allContent => LucideIcons.list,
                        PlanExtensionView.widgets =>
                          LucideIcons.layout_dashboard,
                        PlanExtensionView.bin => LucideIcons.trash,
                        _ => LucideIcons.puzzle,
                      },
                      size: wide ? 15 : 18,
                      color: openView == view
                          ? color.labelPrimary
                          : color.labelSecondary,
                    ),
                    if (wide) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          switch (view) {
                            PlanExtensionView.allContent => context.tr(
                              'planAllContentTitle',
                            ),
                            PlanExtensionView.widgets => context.tr(
                              'planWidgetStrip',
                            ),
                            PlanExtensionView.bin => context.tr('planBinTitle'),
                            _ => context.tr('planGalleryTitle'),
                          },
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DswType.s14.copyWith(
                            color: openView == view
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
    ];
    return groups;
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
  ///
  /// Grouped mode flattens the groups into one line list rather than emitting a
  /// sliver per group: one lazy list, and the folded rows simply are not in it.
  List<Widget> _sessionSlivers(DswAlias color) {
    final sessions = widget.sessions.sessions;
    if (sessions.isEmpty && widget.historyOrganize == HistoryOrganize.flat) {
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

    final lines = <_HistoryLine>[
      if (widget.historyOrganize == HistoryOrganize.flat)
        for (final session in sessions) _HistoryLine.row(session),
      if (widget.historyOrganize == HistoryOrganize.project)
        ..._historyLines(sessions),
    ];

    return [
      if (widget.historyOrganize == HistoryOrganize.project)
        SliverToBoxAdapter(
          child: _HistorySectionRow(
            organize: widget.historyOrganize,
            onOrganizeChanged: widget.onHistoryOrganizeChanged,
            onAddWorkspace: widget.onAddWorkspace,
            groupKeys: [
              for (final line in lines)
                if (line.group != null) line.group!.key,
            ],
            onCollapseAll: widget.onSetCollapsedWorkspaces == null
                ? null
                : (keys) => widget.onSetCollapsedWorkspaces!(keys),
          ),
        ),
      if (lines.isEmpty)
        SliverToBoxAdapter(
          // Grouping must not eat the empty state: a first run has no folder
          // and no conversation, and a column showing only the word
          // 「工作区」 reads as broken rather than as empty.
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
      SliverList.builder(
        itemCount: lines.length,
        itemBuilder: (context, index) {
          final line = lines[index];
          final group = line.group;
          if (group != null) {
            return _WorkspaceGroupRow(
              group: group,
              collapsed: widget.collapsedWorkspaces.contains(group.key),
              isCurrent: _isCurrentFolder(group.workspaceRoot),
              onToggle: () =>
                  widget.onToggleWorkspaceCollapsed?.call(group.key),
              onNewSession:
                  widget.onNewSessionInWorkspace == null || group.isUnassigned
                  ? null
                  : () => widget.onNewSessionInWorkspace!(group.workspaceRoot!),
              menu: _workspaceMenu(group),
            );
          }
          final session = line.session!;
          return DswContextMenu(
            items: (_) => _sessionMenu(session),
            child: _SessionRow(
              session: session,
              selected: session.id == widget.sessions.activeId,
              indented: widget.historyOrganize == HistoryOrganize.project,
              onTap: () => widget.onOpenSession(session.id),
            ),
          );
        },
      ),
    ];
  }

  /// Groups, with a folded group contributing only its header.
  List<_HistoryLine> _historyLines(List<SessionSummary> sessions) {
    final groups = groupSessionsByWorkspace(
      sessions: sessions,
      currentWorkspace: widget.currentWorkspace,
      knownWorkspaces: {
        ...widget.knownWorkspaces,
        ...widget.sessions.knownWorkspaces,
      },
    );
    return [
      for (final group in groups) ...[
        _HistoryLine.header(group),
        if (!widget.collapsedWorkspaces.contains(group.key))
          for (final session in group.sessions) _HistoryLine.row(session),
      ],
    ];
  }

  bool _isCurrentFolder(String? root) =>
      root != null &&
      widget.currentWorkspace != null &&
      workspaceKey(root) == workspaceKey(widget.currentWorkspace!);

  List<DswMenuEntry> _workspaceMenu(WorkspaceGroup group) {
    final root = group.workspaceRoot;
    if (root == null) return const [];
    return [
      DswMenuEntry(
        label: context.tr('showFileTree'),
        icon: LucideIcons.folder_tree,
        onTap: widget.onOpenWorkspaceTree == null
            ? null
            : () => widget.onOpenWorkspaceTree!(root),
      ),
      DswMenuEntry(
        label: context.tr('revealInFinder'),
        icon: LucideIcons.external_link,
        onTap: () async {
          if (await revealInFileManager(root)) return;
          if (!mounted) return;
          showFeedback(context, context.tr('revealFailed'), destructive: true);
        },
      ),
      const DswMenuEntry.divider(),
      DswMenuEntry(
        label: context.tr('removeWorkspace'),
        icon: LucideIcons.circle_minus,
        onTap: widget.onRemoveWorkspace == null
            ? null
            : () => widget.onRemoveWorkspace!(root),
      ),
    ];
  }

  List<DswMenuEntry> _sessionMenu(SessionSummary session) => [
    DswMenuEntry(
      label: context.tr(
        session.pinnedAt == null ? 'pinSession' : 'unpinSession',
      ),
      icon: LucideIcons.pin,
      onTap: () {
        widget.sessions.setPinned(session.id, session.pinnedAt == null);
        _warnIfNotSaved();
      },
    ),
    DswMenuEntry(
      label: context.tr('renameSession'),
      icon: LucideIcons.pencil,
      onTap: () => _rename(session),
    ),
    const DswMenuEntry.divider(),
    DswMenuEntry(
      label: context.tr('copySessionId'),
      icon: LucideIcons.copy,
      onTap: () => Clipboard.setData(ClipboardData(text: session.id)),
    ),
    if (session.workspaceRoot != null) ...[
      DswMenuEntry(
        label: context.tr('copyWorkspacePath'),
        icon: LucideIcons.copy,
        onTap: () =>
            Clipboard.setData(ClipboardData(text: session.workspaceRoot!)),
      ),
      // Upstream puts reveal on the task row as well as the project row
      // (`useTaskListItemContextActions.ts:168-175`): the question being asked
      // is usually "where did this conversation's files go", which is about the
      // conversation, not about a folder header.
      DswMenuEntry(
        label: context.tr('revealInFinder'),
        icon: LucideIcons.external_link,
        onTap: () async {
          if (await revealInFileManager(session.workspaceRoot!)) return;
          if (!mounted) return;
          showFeedback(context, context.tr('revealFailed'), destructive: true);
        },
      ),
    ],
    DswMenuEntry(
      label: context.tr('deleteSession'),
      icon: LucideIcons.trash,
      destructive: true,
      onTap: () => _delete(session),
    ),
  ];

  Future<void> _rename(SessionSummary session) async {
    final next = await _promptForText(
      context,
      title: context.tr('renameSessionTitle'),
      initial: session.title ?? '',
    );
    if (next == null || next.isEmpty) return;
    widget.sessions.rename(session.id, next);
    _warnIfNotSaved();
  }

  /// The sidecar write is the one thing these rows can lose without the screen
  /// showing it: the list answers from memory either way, so the only honest
  /// surface is the action that just failed. Returns whether it failed.
  bool _warnIfNotSaved() {
    if (widget.sessions.metadataError == null) return false;
    showFeedback(context, context.tr('historyNotSaved'), destructive: true);
    return true;
  }

  Future<void> _delete(SessionSummary session) async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.tr('deleteSessionTitle'),
      description: context.tr('deleteSessionBody'),
      confirmLabel: context.tr('deleteSession'),
    );
    if (!confirmed || !mounted) return;
    widget.sessions.remove(session.id);
    if (_warnIfNotSaved()) return;
    showFeedback(context, context.tr('sessionDeleted'));
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
    this.indented = false,
  });

  final SessionSummary session;
  final bool selected;
  final VoidCallback onTap;

  /// Under a group header the row steps in, so the header's folder and its
  /// conversations read as one nest rather than as a flat list with a label.
  final bool indented;

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
            padding: EdgeInsets.only(
              left: 10 + (indented ? DswShape.iconTiny + 6 : 0),
              right: 10,
            ),
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
                if (session.pinnedAt != null) ...[
                  // The pin reads as a glyph, not as a colour: the row already
                  // spends its one colour token on "which one is open".
                  Icon(
                    LucideIcons.pin,
                    size: DswShape.iconCaption,
                    color: color.labelTertiary,
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  () {
                    final when = formatRelativeTime(
                      session.updatedAt,
                      DateTime.now(),
                    );
                    return context.tr(when.key, when.params);
                  }(),
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

  /// One line of the history: a folder's header, or a conversation under it.
}

/// One line of the history: a folder's header, or a conversation under it.
class _HistoryLine {
  const _HistoryLine.header(WorkspaceGroup this.group) : session = null;
  const _HistoryLine.row(SessionSummary this.session) : group = null;

  final WorkspaceGroup? group;
  final SessionSummary? session;
}

/// The folder row. Tapping its label folds the group, `+` starts a conversation
/// in that folder, `⋮` holds what the list and the operating system can do.
///
/// The three targets are siblings in one row at one height. Nesting an icon
/// button inside the fold target is how the sidebar footer ended up with a gear
/// that lit the whole row and answered to two names (`005b76c`).
class _WorkspaceGroupRow extends StatelessWidget {
  const _WorkspaceGroupRow({
    required this.group,
    required this.collapsed,
    required this.isCurrent,
    required this.onToggle,
    required this.onNewSession,
    required this.menu,
  });

  final WorkspaceGroup group;
  final bool collapsed;
  final bool isCurrent;
  final VoidCallback onToggle;
  final VoidCallback? onNewSession;
  final List<DswMenuEntry> menu;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    final label = group.isUnassigned
        ? context.tr('unassignedWorkspace')
        : group.displayName;
    return Semantics(
      // The fold state has to be sayable, not only drawn: a chevron that flips
      // is nothing to a screen reader.
      expanded: !collapsed,
      container: true,
      child: Row(
        children: [
          Expanded(
            child: DswHoverTap(
              onTap: onToggle,
              semanticLabel: label,
              builder: (context, hovered, focused) => Container(
                height: DswShape.rowSession * step,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: hovered ? color.interactiveBgHover : null,
                  borderRadius: BorderRadius.circular(DswShape.control),
                ),
                child: Row(
                  children: [
                    Icon(
                      collapsed
                          ? LucideIcons.chevron_right
                          : LucideIcons.chevron_down,
                      size: DswShape.iconTiny,
                      color: color.labelTertiary,
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      group.isUnassigned
                          ? LucideIcons.inbox
                          : collapsed
                          ? LucideIcons.folder
                          : LucideIcons.folder_open,
                      size: DswShape.iconTiny,
                      color: color.labelSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DswType.xs13.copyWith(
                          height: 18 / 13,
                          fontWeight: FontWeight.w500,
                          color: color.labelSecondary,
                        ),
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      // "This is the folder you are in" as a dot, the same
                      // token the session row uses for "this one is open".
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: color.brandPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox.square(dimension: 6),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (onNewSession != null)
            DswIconButton(
              icon: LucideIcons.plus,
              tooltip: context.tr('newSessionHere'),
              onTap: onNewSession,
              size: 24 * step,
              iconSize: DswShape.iconTiny,
            ),
          if (menu.isNotEmpty)
            DswMenu(
              label: context.tr('workspaceActions'),
              items: (_) => menu,
              trigger: (context) => Icon(
                LucideIcons.ellipsis,
                size: DswShape.iconTiny,
                color: color.labelSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// One line of text asked for the right way: shad's dialog, shad's field, and
/// the `float` radius a dialog owns (ADR-0029). Returns null when dismissed.
Future<String?> _promptForText(
  BuildContext context, {
  required String title,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  final step = MediaQuery.textScalerOf(context).scale(1);
  final result = await showShadDialog<String>(
    context: context,
    builder: (context) => ShadDialog(
      radius: BorderRadius.circular(DswShape.float),
      title: Text(title, style: DswType.sStrong14),
      actions: [
        ShadButton.outline(
          height: 24 * step,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('planCancel')),
        ),
        ShadButton(
          height: 24 * step,
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(context.tr('renameSession')),
        ),
      ],
      child: ShadInput(
        controller: controller,
        style: DswType.s14,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
    ),
  );
  controller.dispose();
  return result;
}

/// The section line above the groups: what the list is called, how it is
/// arranged, and a way to bring another folder into it.
///
/// The second screenshot asks for exactly this row — a 「项目」 head with a `⋮`
/// and a `+` at its right. The organize choice lives in the menu rather than in
/// the settings page because it is a decision about this list, made while
/// looking at it.
class _HistorySectionRow extends StatelessWidget {
  const _HistorySectionRow({
    required this.organize,
    required this.onOrganizeChanged,
    required this.onAddWorkspace,
    required this.groupKeys,
    required this.onCollapseAll,
  });

  final HistoryOrganize organize;
  final ValueChanged<HistoryOrganize>? onOrganizeChanged;
  final VoidCallback? onAddWorkspace;

  /// Every folder currently drawn as a group — what "collapse all" means.
  final List<String> groupKeys;

  /// One writer for the whole fold set, so collapsing everything is one write
  /// rather than one notification per folder.
  final ValueChanged<Set<String>>? onCollapseAll;

  @override
  Widget build(BuildContext context) {
    final color = context.dsw;
    final step = MediaQuery.textScalerOf(context).scale(1);
    final canFold = onCollapseAll != null && groupKeys.isNotEmpty;
    return SizedBox(
      height: DswShape.rowSession * step,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                context.tr('workspaces'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DswType.xxs12.copyWith(
                  height: 16 / 12,
                  fontWeight: FontWeight.w500,
                  color: color.labelTertiary,
                ),
              ),
            ),
          ),
          // The menu belongs to the section, not to the organize choice: a
          // caller that only wired the fold actions still gets the menu, and
          // each block inside it appears only with its own action.
          if (onOrganizeChanged != null || canFold)
            DswMenu(
              label: context.tr('historyView'),
              items: (context) => [
                if (onOrganizeChanged != null) ...[
                  DswMenuEntry(
                    label: context.tr('groupByWorkspace'),
                    icon: LucideIcons.folder_tree,
                    trailing: organize == HistoryOrganize.project
                        ? Icon(
                            LucideIcons.check,
                            size: DswShape.iconTiny,
                            color: color.labelPrimary,
                          )
                        : null,
                    onTap: () => onOrganizeChanged!(HistoryOrganize.project),
                  ),
                  DswMenuEntry(
                    label: context.tr('flatList'),
                    icon: LucideIcons.list,
                    trailing: organize == HistoryOrganize.flat
                        ? Icon(
                            LucideIcons.check,
                            size: DswShape.iconTiny,
                            color: color.labelPrimary,
                          )
                        : null,
                    onTap: () => onOrganizeChanged!(HistoryOrganize.flat),
                  ),
                ],
                if (canFold) ...[
                  const DswMenuEntry.divider(),
                  // Upstream ships these as two header glyphs
                  // (`WorkspaceSidebar.tsx:1072-1095`); in a menu they cost no
                  // seat in a 280px column, which is the constraint that made
                  // the reference's own chrome shed labels first.
                  DswMenuEntry(
                    label: context.tr('expandAll'),
                    icon: LucideIcons.chevron_down,
                    onTap: () => onCollapseAll!(const {}),
                  ),
                  DswMenuEntry(
                    label: context.tr('collapseAll'),
                    icon: LucideIcons.chevron_right,
                    onTap: () => onCollapseAll!(groupKeys.toSet()),
                  ),
                ],
              ],
              trigger: (context) => Icon(
                LucideIcons.ellipsis,
                size: DswShape.iconTiny,
                color: color.labelSecondary,
              ),
            ),
          if (onAddWorkspace != null)
            DswIconButton(
              icon: LucideIcons.plus,
              tooltip: context.tr('addWorkspace'),
              onTap: onAddWorkspace,
              size: 24 * step,
              iconSize: DswShape.iconTiny,
            ),
        ],
      ),
    );
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
