import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../utils/log.dart';
import '../utils/shad_theme_fallback.dart';
import 'board_data.dart';
import 'board_group/group.dart';
import 'board_group/group_data.dart';
import 'reorder_flex/drag_state.dart';
import 'reorder_flex/drag_target_interceptor.dart';
import 'reorder_flex/reorder_flex.dart';
import 'reorder_phantom/phantom_controller.dart';

class BoardPanelScrollController {
  BoardPanelState? _boardState;

  void scrollToBottom(
    String groupId, {
    void Function(BuildContext)? completed,
  }) {
    _boardState?.reorderFlexActionMap[groupId]?.scrollToBottom(completed);
  }
}

/// Responsive group column constraints that adapt based on viewport width.
///
/// Uses shadcn_ui's breakpoint system to apply different column widths per
/// screen size. Falls back to [defaultConstraints] for any breakpoint not
/// explicitly configured. Uses Tailwind-style `>=` comparison: each breakpoint
/// targets its size AND all larger sizes unless overridden.
///
/// Example:
/// ```dart
/// ResponsiveGroupConstraints(
///   defaultConstraints: const BoxConstraints(maxWidth: 200),
///   md: const BoxConstraints(maxWidth: 240),
///   xl: const BoxConstraints(maxWidth: 280),
/// )
/// ```
class ResponsiveGroupConstraints {
  const ResponsiveGroupConstraints({
    this.defaultConstraints = const BoxConstraints(maxWidth: 200),
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.xxl,
  });

  /// Default constraints used when no breakpoint-specific override matches.
  final BoxConstraints defaultConstraints;

  /// Constraints for small screens (>= 640px).
  final BoxConstraints? sm;

  /// Constraints for medium screens (>= 768px).
  final BoxConstraints? md;

  /// Constraints for large screens (>= 1024px).
  final BoxConstraints? lg;

  /// Constraints for extra large screens (>= 1280px).
  final BoxConstraints? xl;

  /// Constraints for extra extra large screens (>= 1536px).
  final BoxConstraints? xxl;

  /// Resolves the effective [BoxConstraints] for the given [breakpoint].
  ///
  /// Uses the `>=` operator (Tailwind-style), meaning each breakpoint
  /// targets its size AND all larger sizes unless overridden.
  BoxConstraints resolve(
    ShadBreakpoint breakpoint,
    ShadBreakpoints breakpoints,
  ) {
    if (xxl != null && breakpoint >= breakpoints.xxl) return xxl!;
    if (xl != null && breakpoint >= breakpoints.xl) return xl!;
    if (lg != null && breakpoint >= breakpoints.lg) return lg!;
    if (md != null && breakpoint >= breakpoints.md) return md!;
    if (sm != null && breakpoint >= breakpoints.sm) return sm!;
    return defaultConstraints;
  }
}

/// Responsive board layout direction that adapts based on viewport width.
///
/// Uses shadcn_ui's breakpoint system with Tailwind-style `>=` comparison,
/// mirroring [ResponsiveGroupConstraints]. Groups are laid out horizontally
/// (classic kanban columns) or stacked vertically (mobile-friendly list).
///
/// Example — vertical on phones, horizontal from tablet (md) upwards:
/// ```dart
/// BoardPanelConfig(
///   responsiveDirection: ResponsiveBoardDirection.mobileVertical(),
/// )
/// ```
class ResponsiveBoardDirection {
  const ResponsiveBoardDirection({
    this.defaultDirection = Axis.horizontal,
    this.sm,
    this.md,
    this.lg,
    this.xl,
    this.xxl,
  });

  /// Preset: vertical below the `md` breakpoint (phones), horizontal on
  /// tablet/desktop sizes.
  const ResponsiveBoardDirection.mobileVertical()
    : this(defaultDirection: Axis.vertical, md: Axis.horizontal);

  /// Direction used when no breakpoint-specific override matches.
  final Axis defaultDirection;

  /// Direction for small screens (>= 640px).
  final Axis? sm;

  /// Direction for medium screens (>= 768px).
  final Axis? md;

  /// Direction for large screens (>= 1024px).
  final Axis? lg;

  /// Direction for extra large screens (>= 1280px).
  final Axis? xl;

  /// Direction for extra extra large screens (>= 1536px).
  final Axis? xxl;

  /// Resolves the effective [Axis] for the given [breakpoint].
  ///
  /// Uses the `>=` operator (Tailwind-style), meaning each breakpoint
  /// targets its size AND all larger sizes unless overridden.
  Axis resolve(ShadBreakpoint breakpoint, ShadBreakpoints breakpoints) {
    if (xxl != null && breakpoint >= breakpoints.xxl) return xxl!;
    if (xl != null && breakpoint >= breakpoints.xl) return xl!;
    if (lg != null && breakpoint >= breakpoints.lg) return lg!;
    if (md != null && breakpoint >= breakpoints.md) return md!;
    if (sm != null && breakpoint >= breakpoints.sm) return sm!;
    return defaultDirection;
  }
}

class BoardPanelConfig {
  const BoardPanelConfig({
    this.boardCornerRadius = 6.0,
    this.groupCornerRadius = 6.0,
    this.groupBackgroundColor = const Color(0x00000000),
    this.groupMargin = const EdgeInsets.symmetric(horizontal: 8),
    this.groupHeaderPadding = const EdgeInsets.symmetric(horizontal: 16),
    this.groupBodyPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.groupFooterPadding = const EdgeInsets.symmetric(horizontal: 12),
    this.stretchGroupHeight = true,
    this.cardMargin = const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
    this.dragAutoScrollVelocity = 30.0,
    this.cardPageSize = 10,
    this.loadMoreTriggerOffset = 80.0,
    this.responsiveGroupConstraints,
    this.responsiveDirection,
    this.verticalGroupMargin = const EdgeInsets.symmetric(vertical: 8),
    this.verticalGroupConstraints = const BoxConstraints(),
  });

  // board
  final double boardCornerRadius;

  // group
  final double groupCornerRadius;
  final Color groupBackgroundColor;
  final EdgeInsets groupMargin;
  final EdgeInsets groupHeaderPadding;
  final EdgeInsets groupBodyPadding;
  final EdgeInsets groupFooterPadding;
  final bool stretchGroupHeight;

  // card
  final EdgeInsets cardMargin;

  /// The velocity scalar for auto-scrolling when dragging cards near edges.
  /// Lower values result in slower scrolling. Default is 30.0.
  /// Increase this value for faster scrolling, decrease for slower.
  final double dragAutoScrollVelocity;

  /// Number of cards to render per "page" when lazy loading.
  /// Set to 0 or less to render all cards.
  final int cardPageSize;

  /// Distance from the bottom that triggers loading more cards.
  final double loadMoreTriggerOffset;

  /// Responsive group column constraints that adapt based on viewport width.
  /// When set, the column width will automatically adjust when the viewport
  /// width crosses shadcn_ui breakpoints.
  final ResponsiveGroupConstraints? responsiveGroupConstraints;

  /// Responsive board layout direction. When set, the board switches between
  /// horizontal columns and a vertical stack as the viewport width crosses
  /// shadcn_ui breakpoints. When null (default) the board stays horizontal,
  /// preserving the previous behavior.
  final ResponsiveBoardDirection? responsiveDirection;

  /// Margin applied around each group when the board is laid out vertically.
  final EdgeInsets verticalGroupMargin;

  /// Constraints applied to each group when the board is laid out vertically.
  /// Groups expand to the full available width by default; use this to cap
  /// e.g. the group height.
  final BoxConstraints verticalGroupConstraints;
}

class BoardPanel extends StatelessWidget {
  const BoardPanel({
    super.key,
    required this.controller,
    required this.cardBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.background,
    this.groupConstraints = const BoxConstraints(maxWidth: 200),
    this.scrollController,
    this.config = const BoardPanelConfig(),
    this.boardScrollController,
    this.onLoadMore,
    this.hasMore,
    this.loadingWidgetBuilder,
    this.leading,
    this.trailing,
    this.shrinkWrap = false,
    this.responsiveGroupConstraints,
  });

  /// A controller for [BoardPanel] widget.
  ///
  /// A [BoardPanelController] can be used to provide an initial value of
  /// the board by calling `addGroup` method with the passed in parameter
  /// [BoardPanelGroupData]. A [BoardPanelGroupData] represents one
  /// group data. Whenever the user modifies the board, this controller will
  /// update the corresponding group data.
  ///
  /// Also, you can register the callbacks that receive the changes. Check out
  /// the [BoardPanelController] for more information.
  ///
  final BoardPanelController controller;

  /// The widget that will be rendered as the background of the board.
  final Widget? background;

  /// The [cardBuilder] function which will be invoked on each card build.
  /// The [cardBuilder] takes the [BuildContext],[BoardPanelGroupData] and
  /// the corresponding [BoardPanelGroupItem].
  ///
  /// must return a widget.
  final BoardPanelCardBuilder cardBuilder;

  /// The [headerBuilder] function which will be invoked on each group build.
  /// The [headerBuilder] takes the [BuildContext] and [BoardPanelGroupData].
  ///
  /// must return a widget.
  final BoardPanelHeaderBuilder? headerBuilder;

  /// The [footerBuilder] function which will be invoked on each group build.
  /// The [footerBuilder] takes the [BuildContext] and [BoardPanelGroupData].
  ///
  /// must return a widget.
  final BoardPanelFooterBuilder? footerBuilder;

  /// A constraints applied to [BoardPanelGroup] widget.
  final BoxConstraints groupConstraints;

  /// A controller is used by the [ReorderFlex].
  ///
  /// The [ReorderFlex] will used the primary scrollController of the current
  /// [BuildContext] by using PrimaryScrollController.of(context).
  /// If the primary scrollController is null, we will assign a new [ScrollController].
  final ScrollController? scrollController;

  final BoardPanelConfig config;

  /// A controller is used to control each group scroll actions.
  ///
  final BoardPanelScrollController? boardScrollController;

  /// Called when a group scrolls near the bottom to load more cards.
  final OnLoadMoreCards? onLoadMore;

  /// Returns true if a group has more cards to load.
  final HasMoreCards? hasMore;

  /// Custom builder for the loading indicator widget.
  /// If not provided, a default CircularProgressIndicator will be used.
  final LoadingWidgetBuilder? loadingWidgetBuilder;

  /// A widget that is shown before the first group in the Board
  ///
  final Widget? leading;

  /// A widget that is shown after the last group in the Board
  ///
  final Widget? trailing;

  /// if [shrinkWrap] is true, the height of board will be dynamic
  final bool shrinkWrap;

  /// Responsive group column constraints that adapt based on viewport width.
  /// When set, overrides the static [groupConstraints] for dynamic column
  /// sizing across different screen sizes.
  final ResponsiveGroupConstraints? responsiveGroupConstraints;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        return _BoardPanelContent(
          config: config,
          boardController: controller,
          scrollController: scrollController,
          scrollManager: boardScrollController,
          background: background,
          groupConstraints: groupConstraints,
          cardBuilder: cardBuilder,
          footerBuilder: footerBuilder,
          headerBuilder: headerBuilder,
          onLoadMore: onLoadMore,
          hasMore: hasMore,
          loadingWidgetBuilder: loadingWidgetBuilder,
          onReorder: controller.moveGroup,
          leading: leading,
          trailing: trailing,
          shrinkWrap: shrinkWrap,
          responsiveGroupConstraints: responsiveGroupConstraints,
        );
      },
    );
  }
}

class _BoardPanelContent extends StatefulWidget {
  _BoardPanelContent({
    required this.config,
    required this.onReorder,
    required this.boardController,
    required this.scrollManager,
    required this.groupConstraints,
    required this.cardBuilder,
    this.onLoadMore,
    this.hasMore,
    this.loadingWidgetBuilder,
    this.leading,
    this.trailing,
    this.shrinkWrap = false,
    this.scrollController,
    this.background,
    this.headerBuilder,
    this.footerBuilder,
    this.responsiveGroupConstraints,
  }) : reorderFlexConfig = ReorderFlexConfig(
         direction: Axis.horizontal,
         dragDirection: Axis.horizontal,
         autoScrollVelocityScalar: config.dragAutoScrollVelocity,
       );

  final BoardPanelConfig config;
  final OnReorder onReorder;
  final BoardPanelController boardController;
  final BoardPanelScrollController? scrollManager;
  final BoxConstraints groupConstraints;
  final BoardPanelCardBuilder cardBuilder;
  final OnLoadMoreCards? onLoadMore;
  final HasMoreCards? hasMore;
  final LoadingWidgetBuilder? loadingWidgetBuilder;
  final Widget? leading;
  final Widget? trailing;
  final ScrollController? scrollController;
  final Widget? background;
  final bool shrinkWrap;
  final BoardPanelHeaderBuilder? headerBuilder;
  final BoardPanelFooterBuilder? footerBuilder;
  final ReorderFlexConfig reorderFlexConfig;

  /// Responsive group column constraints that adapt based on viewport width.
  final ResponsiveGroupConstraints? responsiveGroupConstraints;

  @override
  State<_BoardPanelContent> createState() => _BoardPanelContentState();
}

class _BoardPanelContentState extends State<_BoardPanelContent> {
  late final _scrollController = widget.scrollController ?? ScrollController();
  late BoardPanelState _boardState;
  late BoardPhantomController _phantomController;

  @override
  void initState() {
    super.initState();
    _initBoardControllers();
  }

  @override
  void didUpdateWidget(covariant _BoardPanelContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.boardController != widget.boardController) {
      if (oldWidget.scrollManager != widget.scrollManager) {
        oldWidget.scrollManager?._boardState = null;
      }
      _initBoardControllers();
      return;
    }

    if (oldWidget.scrollManager != widget.scrollManager) {
      oldWidget.scrollManager?._boardState = null;
      widget.scrollManager?._boardState = _boardState;
    }
  }

  @override
  void dispose() {
    // Dispose internally created scroll controller
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _initBoardControllers() {
    _boardState = BoardPanelState();
    _phantomController = BoardPhantomController(
      delegate: widget.boardController,
      groupsState: _boardState,
    );
    widget.scrollManager?._boardState = _boardState;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    final effectiveRadius = BorderRadius.circular(
      widget.config.boardCornerRadius,
    );

    final scrollbarTheme = theme != null
        ? ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(
              theme.colorScheme.primary.withAlpha(80),
            ),
            trackColor: WidgetStateProperty.all(
              theme.colorScheme.background.withAlpha(0),
            ),
            thickness: WidgetStateProperty.all(6.0),
            radius: const Radius.circular(3.0),
          )
        : null;

    return ShadThemeFallback(
      child: ShadResponsiveBuilder(
        builder: (context, breakpoint) {
          final effectiveDirection = _resolveDirection(breakpoint, context);
          final isVertical = effectiveDirection == Axis.vertical;
          final effectiveConstraints = isVertical
              ? widget.config.verticalGroupConstraints
              : _resolveConstraints(breakpoint, context);
          // Rebuild the flex config only when leaving the default horizontal
          // layout; drag direction always follows the board direction.
          final effectiveFlexConfig = isVertical
              ? ReorderFlexConfig(
                  direction: Axis.vertical,
                  dragDirection: Axis.vertical,
                  autoScrollVelocityScalar:
                      widget.config.dragAutoScrollVelocity,
                )
              : widget.reorderFlexConfig;
          _syncControllerDirection(effectiveDirection);
          return Stack(
            fit: StackFit.passthrough,
            children: [
              if (widget.background != null)
                Container(
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(borderRadius: effectiveRadius),
                  child: widget.background,
                ),
              Theme(
                data: Theme.of(context).copyWith(
                  scrollbarTheme:
                      scrollbarTheme ?? Theme.of(context).scrollbarTheme,
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    scrollDirection: effectiveFlexConfig.direction,
                    controller: _scrollController,
                    child: ReorderFlex(
                      // Re-key on direction so drag state and animations are
                      // rebuilt cleanly when the layout axis flips.
                      key: ValueKey(effectiveDirection),
                      config: effectiveFlexConfig,
                      scrollController: _scrollController,
                      onReorder: widget.onReorder,
                      dataSource: widget.boardController,
                      autoScroll: true,
                      interceptor: OverlappingDragTargetInterceptor(
                        reorderFlexId: widget.boardController.identifier,
                        acceptedReorderFlexId: widget.boardController.groupIds,
                        delegate: _phantomController,
                        columnsState: _boardState,
                      ),
                      leading: widget.leading,
                      trailing: widget.trailing,
                      children: _buildColumns(
                        effectiveConstraints,
                        effectiveDirection,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Resolves the board layout axis for the current [breakpoint].
  Axis _resolveDirection(ShadBreakpoint breakpoint, BuildContext context) {
    final responsive = widget.config.responsiveDirection;
    if (responsive != null) {
      final breakpoints = ShadTheme.of(context).breakpoints;
      return responsive.resolve(breakpoint, breakpoints);
    }
    return widget.reorderFlexConfig.direction;
  }

  /// Publishes the resolved direction to the controller after the frame,
  /// so listeners (headers, business layer) can react without triggering
  /// notifications during build.
  void _syncControllerDirection(Axis direction) {
    if (widget.boardController.layoutDirection.value == direction) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.boardController.updateLayoutDirection(direction);
    });
  }

  BoxConstraints _resolveConstraints(
    ShadBreakpoint breakpoint,
    BuildContext context,
  ) {
    final responsive =
        widget.responsiveGroupConstraints ??
        widget.config.responsiveGroupConstraints;
    if (responsive != null) {
      final breakpoints = ShadTheme.of(context).breakpoints;
      return responsive.resolve(breakpoint, breakpoints);
    }
    return widget.groupConstraints;
  }

  List<Widget> _buildColumns(BoxConstraints groupConstraints, Axis direction) {
    final List<Widget> children = [];
    final isVertical = direction == Axis.vertical;

    widget.boardController.groupDatas.asMap().entries.map((item) {
      final columnData = item.value;
      final columnIndex = item.key;

      final dataSource = _BoardGroupDataSourceImpl(
        groupId: columnData.id,
        boardController: widget.boardController,
      );

      final reorderFlexAction = ReorderFlexActionImpl();
      _boardState.reorderFlexActionMap[columnData.id] = reorderFlexAction;

      children.add(
        ListenableBuilder(
          key: ValueKey(columnData.id),
          listenable: widget.boardController.getGroupController(columnData.id)!,
          builder: (context, child) {
            final group = ConstrainedBox(
              constraints: groupConstraints,
              child: BoardPanelGroup(
                margin: _marginFromIndex(columnIndex, direction),
                bodyPadding: widget.config.groupBodyPadding,
                headerBuilder: _buildHeader,
                footerBuilder: widget.footerBuilder,
                cardBuilder: widget.cardBuilder,
                dataSource: dataSource,
                // Each group owns its scroll controller (see
                // `_BoardPanelGroupState._ownedScrollController`): a shared one
                // would be attached twice while the group is dragged, because
                // the drag feedback mounts the very same group widget again.
                // Vertical boards stack intrinsically sized groups inside a
                // single scroll view, so groups must shrink-wrap to avoid
                // unbounded-height flex errors.
                shrinkWrap: isVertical || widget.shrinkWrap,
                phantomController: _phantomController,
                onReorder: widget.boardController.moveGroupItem,
                cornerRadius: widget.config.groupCornerRadius,
                backgroundColor: widget.config.groupBackgroundColor,
                dragStateStorage: _boardState,
                dragTargetKeys: _boardState,
                reorderFlexAction: reorderFlexAction,
                stretchGroupHeight:
                    !isVertical && widget.config.stretchGroupHeight,
                cardPageSize: widget.config.cardPageSize,
                loadMoreTriggerOffset: widget.config.loadMoreTriggerOffset,
                onLoadMore: widget.onLoadMore,
                hasMore: widget.hasMore,
                loadingWidgetBuilder: widget.loadingWidgetBuilder,
                onDragStarted: (index) {
                  widget.boardController.onStartDraggingCard?.call(
                    columnData.id,
                    index,
                  );
                },
              ),
            );
            // Stretch groups to the full available width when stacked
            // vertically.
            return isVertical
                ? SizedBox(width: double.infinity, child: group)
                : group;
          },
        ),
      );
    }).toList();

    return children;
  }

  Widget? _buildHeader(
    BuildContext context,
    BoardPanelGroupData<dynamic> groupData,
  ) {
    if (widget.headerBuilder == null) {
      return null;
    }
    return ListenableBuilder(
      listenable: widget.boardController.getGroupController(groupData.id)!,
      builder: (context, child) => widget.headerBuilder!(context, groupData)!,
    );
  }

  EdgeInsets _marginFromIndex(int index, Axis direction) {
    final isVertical = direction == Axis.vertical;
    final margin = isVertical
        ? widget.config.verticalGroupMargin
        : widget.config.groupMargin;

    if (widget.boardController.groupDatas.isEmpty) {
      return margin;
    }

    if (index == 0) {
      // remove the leading padding of the first group
      return isVertical ? margin.copyWith(top: 0) : margin.copyWith(left: 0);
    }

    if (index == widget.boardController.groupDatas.length - 1) {
      // remove the trailing padding of the last group
      return isVertical
          ? margin.copyWith(bottom: 0)
          : margin.copyWith(right: 0);
    }

    return margin;
  }
}

class _BoardGroupDataSourceImpl extends BoardPanelGroupDataDataSource {
  _BoardGroupDataSourceImpl({
    required this.groupId,
    required this.boardController,
  });

  final String groupId;
  final BoardPanelController boardController;

  @override
  BoardPanelGroupData<dynamic> get groupData =>
      boardController.getGroupController(groupId)!.groupData;

  @override
  List<String> get acceptedGroupIds => boardController.groupIds;
}

class BoardPanelState extends DraggingStateStorage
    implements ReorderDragTargetKeys {
  final Map<String, DraggingState> groupDragStates = {};
  final Map<String, Map<String, GlobalObjectKey>> groupDragTargetKeys = {};

  /// Quick access to the [BoardPanelGroup], the [GlobalKey] is bind to the
  /// BoardPanelGroup's [ReorderFlex] widget.
  final Map<String, ReorderFlexActionImpl> reorderFlexActionMap = {};

  @override
  DraggingState? readState(String reorderFlexId) =>
      groupDragStates[reorderFlexId];

  @override
  void insertState(String reorderFlexId, DraggingState state) {
    Log.trace('$reorderFlexId Write dragging state: $state');
    groupDragStates[reorderFlexId] = state;
  }

  @override
  void removeState(String reorderFlexId) {
    groupDragStates.remove(reorderFlexId);
  }

  @override
  void insertDragTarget(
    String reorderFlexId,
    String key,
    GlobalObjectKey<State<StatefulWidget>> value,
  ) {
    Map<String, GlobalObjectKey>? group = groupDragTargetKeys[reorderFlexId];
    if (group == null) {
      group = {};
      groupDragTargetKeys[reorderFlexId] = group;
    }
    group[key] = value;
  }

  @override
  GlobalObjectKey<State<StatefulWidget>>? getDragTarget(
    String reorderFlexId,
    String key,
  ) {
    final Map<String, GlobalObjectKey>? group =
        groupDragTargetKeys[reorderFlexId];
    if (group != null) {
      return group[key];
    }

    return null;
  }

  @override
  void removeDragTarget(String reorderFlexId) {
    groupDragTargetKeys.remove(reorderFlexId);
  }
}

class ReorderFlexActionImpl extends ReorderFlexAction {}
