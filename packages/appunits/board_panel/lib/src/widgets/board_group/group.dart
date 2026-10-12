import 'dart:collection';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../utils/log.dart';
import '../../utils/shad_theme_fallback.dart';
import '../reorder_flex/drag_state.dart';
import '../reorder_flex/drag_target_interceptor.dart';
import '../reorder_flex/reorder_flex.dart';
import '../reorder_phantom/phantom_controller.dart';
import 'group_data.dart';

typedef OnGroupDragStarted = void Function(int index);

typedef OnGroupDragEnded = void Function(String groupId);

typedef OnGroupReorder =
    void Function(String groupId, int fromIndex, int toIndex);

typedef BoardPanelCardBuilder =
    Widget Function(
      BuildContext context,
      BoardPanelGroupData<dynamic> groupData,
      BoardPanelGroupItem item,
    );

typedef BoardPanelHeaderBuilder =
    Widget? Function(
      BuildContext context,
      BoardPanelGroupData<dynamic> groupData,
    );

typedef BoardPanelFooterBuilder =
    Widget Function(
      BuildContext context,
      BoardPanelGroupData<dynamic> groupData,
    );

typedef OnLoadMoreCards =
    Future<void> Function(BoardPanelGroupData<dynamic> groupData);

typedef HasMoreCards = bool Function(BoardPanelGroupData<dynamic> groupData);

typedef LoadingWidgetBuilder = Widget Function(BuildContext context);

abstract class BoardPanelGroupDataDataSource implements ReoderFlexDataSource {
  BoardPanelGroupData<dynamic> get groupData;

  List<String> get acceptedGroupIds;

  @override
  String get identifier => groupData.id;

  @override
  UnmodifiableListView<BoardPanelGroupItem> get items => groupData.items;

  void debugPrint() {
    String msg = '[$BoardPanelGroupDataDataSource] $groupData data: ';
    for (final element in items) {
      msg = '$msg$element,';
    }

    Log.debug(msg);
  }
}

/// A [BoardPanelGroup] represents the group UI of the Board.
///
class BoardPanelGroup extends StatefulWidget {
  const BoardPanelGroup({
    super.key,
    required this.cardBuilder,
    required this.onReorder,
    required this.dataSource,
    required this.phantomController,
    this.headerBuilder,
    this.footerBuilder,
    this.reorderFlexAction,
    this.dragStateStorage,
    this.dragTargetKeys,
    this.scrollController,
    this.onDragStarted,
    this.onDragEnded,
    this.margin = EdgeInsets.zero,
    this.bodyPadding = EdgeInsets.zero,
    this.cornerRadius = 0.0,
    this.backgroundColor = const Color(0x00000000),
    this.stretchGroupHeight = true,
    this.shrinkWrap = false,
    this.cardPageSize = 0,
    this.loadMoreTriggerOffset = 80.0,
    this.onLoadMore,
    this.hasMore,
    this.loadingWidgetBuilder,
  }) : config = const ReorderFlexConfig();

  final BoardPanelCardBuilder cardBuilder;
  final OnGroupReorder onReorder;
  final BoardPanelGroupDataDataSource dataSource;
  final BoardPhantomController phantomController;
  final BoardPanelHeaderBuilder? headerBuilder;
  final BoardPanelFooterBuilder? footerBuilder;
  final ReorderFlexAction? reorderFlexAction;
  final DraggingStateStorage? dragStateStorage;
  final ReorderDragTargetKeys? dragTargetKeys;

  final ScrollController? scrollController;
  final OnGroupDragStarted? onDragStarted;

  final OnGroupDragEnded? onDragEnded;
  final EdgeInsets margin;
  final EdgeInsets bodyPadding;
  final double cornerRadius;
  final Color backgroundColor;
  final bool stretchGroupHeight;
  final bool shrinkWrap;
  final ReorderFlexConfig config;
  final int cardPageSize;
  final double loadMoreTriggerOffset;
  final OnLoadMoreCards? onLoadMore;
  final HasMoreCards? hasMore;

  /// Custom builder for the loading indicator widget.
  /// If not provided, a default CircularProgressIndicator will be used.
  final LoadingWidgetBuilder? loadingWidgetBuilder;

  String get groupId => dataSource.groupData.id;

  @override
  State<BoardPanelGroup> createState() => _BoardPanelGroupState();
}

class _BoardPanelGroupState extends State<BoardPanelGroup> {
  ScrollController? _scrollController;
  int _visibleCount = 0;
  bool _isLoadingMore = false;
  int _lastTotalItems = 0;

  /// Fallback controller created when the host does not supply one.
  ///
  /// Owning it per [State] is deliberate: while a group is being dragged the
  /// same group widget is mounted more than once (the drag feedback and
  /// `childWhenDragging` both build it), and a controller shared across those
  /// copies would end up attached to several scroll views — which trips
  /// `ScrollController.position`'s `_positions.length == 1` assertion. Each
  /// mounted copy gets its own [State], hence its own controller.
  ScrollController? _ownedScrollController;

  /// The controller driving this group's scroll view.
  ScrollController get _effectiveScrollController =>
      widget.scrollController ??
      (_ownedScrollController ??= ScrollController());

  @override
  void initState() {
    super.initState();
    _initVisibleCount();
    _attachScrollController(_effectiveScrollController);
  }

  @override
  void didUpdateWidget(covariant BoardPanelGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _attachScrollController(_effectiveScrollController);
    }

    if (oldWidget.cardPageSize != widget.cardPageSize) {
      _initVisibleCount();
    }
  }

  @override
  void dispose() {
    _detachScrollController();
    _ownedScrollController?.dispose();
    _ownedScrollController = null;
    super.dispose();
  }

  void _attachScrollController(ScrollController? controller) {
    _detachScrollController();
    _scrollController = controller;
    _scrollController?.addListener(_onScroll);
  }

  void _detachScrollController() {
    _scrollController?.removeListener(_onScroll);
    _scrollController = null;
  }

  void _initVisibleCount() {
    final totalItems = widget.dataSource.groupData.items.length;
    if (widget.cardPageSize <= 0) {
      _visibleCount = totalItems;
      _lastTotalItems = totalItems;
      return;
    }
    _visibleCount = min(widget.cardPageSize, totalItems);
    _lastTotalItems = totalItems;
  }

  void _syncVisibleCount(int totalItems) {
    if (widget.cardPageSize <= 0) {
      _visibleCount = totalItems;
      _lastTotalItems = totalItems;
      return;
    }

    if (_lastTotalItems == 0 && totalItems > 0) {
      _visibleCount = min(widget.cardPageSize, totalItems);
      _lastTotalItems = totalItems;
      return;
    }

    if (totalItems < _lastTotalItems) {
      if (_visibleCount > totalItems) {
        _visibleCount = totalItems;
      }
    } else if (totalItems > _lastTotalItems) {
      final added = totalItems - _lastTotalItems;
      if (_visibleCount >= _lastTotalItems) {
        _visibleCount = min(_visibleCount + added, totalItems);
      }
    }

    _lastTotalItems = totalItems;
  }

  void _onScroll() {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return;

    final position = controller.position;
    final threshold = widget.loadMoreTriggerOffset;
    if (position.pixels >= position.maxScrollExtent - threshold) {
      _maybeLoadMore();
    }
  }

  Future<void> _maybeLoadMore() async {
    if (_isLoadingMore || widget.cardPageSize <= 0) {
      return;
    }

    final totalItems = widget.dataSource.groupData.items.length;
    final hasHiddenItems = _visibleCount < totalItems;
    final hasMoreOverride = widget.hasMore?.call(widget.dataSource.groupData);
    if (hasMoreOverride == false) {
      return;
    }
    final hasMore =
        hasMoreOverride ?? hasHiddenItems || widget.onLoadMore != null;

    if (!hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      await widget.onLoadMore?.call(widget.dataSource.groupData);
    } finally {
      if (mounted) {
        final updatedTotal = widget.dataSource.groupData.items.length;
        setState(() {
          _isLoadingMore = false;
          _visibleCount = min(
            _visibleCount + widget.cardPageSize,
            updatedTotal,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    final items = widget.dataSource.groupData.items;
    final totalItems = items.length;
    _syncVisibleCount(totalItems);
    final visibleCount = widget.cardPageSize <= 0
        ? totalItems
        : min(_visibleCount, totalItems);
    final visibleItems = items.take(visibleCount).toList();
    final children = visibleItems
        .map((item) => _buildWidget(context, item))
        .toList();

    // Check if there are more items to load
    final hasMoreItems =
        visibleCount < totalItems ||
        (widget.hasMore?.call(widget.dataSource.groupData) ?? false);

    // Build loading indicator widget (placed outside ReorderFlex)
    Widget? loadingIndicator;
    if (_isLoadingMore && hasMoreItems) {
      loadingIndicator =
          widget.loadingWidgetBuilder?.call(context) ??
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: ShadProgress(minHeight: 4),
          );
    }

    final header = widget.headerBuilder?.call(
      context,
      widget.dataSource.groupData,
    );

    final footer = widget.footerBuilder?.call(
      context,
      widget.dataSource.groupData,
    );

    final dataSource = _LimitedGroupDataSource(
      base: widget.dataSource,
      items: visibleItems,
    );

    final interceptor = CrossReorderFlexDragTargetInterceptor(
      reorderFlexId: widget.groupId,
      delegate: widget.phantomController,
      acceptedReorderFlexIds: widget.dataSource.acceptedGroupIds,
      draggableTargetBuilder: PhantomDraggableBuilder(),
    );

    final reorderFlex = ReorderFlex(
      key: ValueKey(widget.groupId),
      dragStateStorage: widget.dragStateStorage,
      dragTargetKeys: widget.dragTargetKeys,
      scrollController: _effectiveScrollController,
      config: widget.config,
      onDragStarted: (index) {
        widget.phantomController.groupStartDragging(widget.groupId);
        widget.onDragStarted?.call(index);
      },
      onReorder: (fromIndex, toIndex) {
        if (widget.phantomController.shouldReorder(widget.groupId)) {
          widget.onReorder(widget.groupId, fromIndex, toIndex);
          widget.phantomController.updateIndex(fromIndex, toIndex);
        }
      },
      onDragEnded: () {
        widget.phantomController.groupEndDragging(widget.groupId);
        widget.onDragEnded?.call(widget.groupId);
        widget.dataSource.debugPrint();
      },
      dataSource: dataSource,
      interceptor: interceptor,
      reorderFlexAction: widget.reorderFlexAction,
      children: children,
    );

    // Only wrap in Column if we have a loading indicator to show
    final scrollContent = loadingIndicator != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [reorderFlex, loadingIndicator],
          )
        : reorderFlex;

    final paddingWidget = Padding(
      padding: widget.bodyPadding,
      child: SingleChildScrollView(
        scrollDirection: widget.config.direction,
        controller: _effectiveScrollController,
        child: scrollContent,
      ),
    );

    final reorderWidget = widget.shrinkWrap
        ? paddingWidget
        : Flexible(
            fit: widget.stretchGroupHeight ? FlexFit.tight : FlexFit.loose,
            child: paddingWidget,
          );

    final childrenWidgets = [?header, reorderWidget, ?footer];

    Widget content = widget.shrinkWrap
        ? Column(mainAxisSize: MainAxisSize.min, children: childrenWidgets)
        : Flex(
            direction: Axis.vertical,
            mainAxisSize: MainAxisSize.min,
            children: childrenWidgets,
          );

    content = widget.cornerRadius > 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(widget.cornerRadius),
            child: content,
          )
        : ClipRect(child: content);

    final effectiveBgColor = widget.backgroundColor != const Color(0x00000000)
        ? widget.backgroundColor
        : (theme?.colorScheme.background ?? widget.backgroundColor);

    final effectiveRadius = widget.cornerRadius > 0
        ? BorderRadius.circular(widget.cornerRadius)
        : (theme?.radius ?? BorderRadius.zero);

    return ShadThemeFallback(
      child: Container(
        margin: widget.margin,
        decoration: BoxDecoration(
          color: effectiveBgColor,
          borderRadius: effectiveRadius,
        ),
        child: content,
      ),
    );
  }

  Widget _buildWidget(BuildContext context, BoardPanelGroupItem item) {
    if (item is PhantomGroupItem) {
      return PassthroughPhantomWidget(
        key: UniqueKey(),
        opacity: widget.config.draggingWidgetOpacity,
        passthroughPhantomContext: item.phantomContext,
      );
    }

    final card = widget.cardBuilder(context, widget.dataSource.groupData, item);
    return RepaintBoundary(key: ValueKey(item.id), child: card);
  }
}

class _LimitedGroupDataSource extends BoardPanelGroupDataDataSource {
  _LimitedGroupDataSource({
    required this.base,
    required List<BoardPanelGroupItem> items,
  }) : _items = UnmodifiableListView(items);

  final BoardPanelGroupDataDataSource base;
  final UnmodifiableListView<BoardPanelGroupItem> _items;

  @override
  BoardPanelGroupData<dynamic> get groupData => base.groupData;

  @override
  List<String> get acceptedGroupIds => base.acceptedGroupIds;

  @override
  UnmodifiableListView<BoardPanelGroupItem> get items => _items;
}
