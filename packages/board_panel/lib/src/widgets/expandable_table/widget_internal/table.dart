// Flutter imports:
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

// Project imports:
import '../../../../board_panel.dart';
import '../../../utils/linked_scroll_controller.dart';
// Package imports:
import '../../../utils/scroll_shadow.dart';
import '../widget_internal/animated_container.dart';
import '../widget_internal/cell.dart';

/// [InternalTable] it is the widget that builds the table.
class InternalTable extends ConsumerStatefulWidget {
  /// [InternalTable] constructor.
  const InternalTable({super.key});

  @override
  InternalTableState createState() => InternalTableState();
}

/// [InternalTable] state.
class InternalTableState extends ConsumerState<InternalTable> {
  late LinkedScrollControllerGroup _horizontalLinkedControllers;
  late ScrollController _headController;
  late ScrollController _horizontalBodyController;
  late LinkedScrollControllerGroup _verticalLinkedControllers;
  late ScrollController _firstColumnController;
  late ScrollController _restColumnsController;

  @override
  void initState() {
    super.initState();
    _horizontalLinkedControllers = LinkedScrollControllerGroup();
    _headController = _horizontalLinkedControllers.addAndGet();
    _horizontalBodyController = _horizontalLinkedControllers.addAndGet();
    _verticalLinkedControllers = LinkedScrollControllerGroup();
    _firstColumnController = _verticalLinkedControllers.addAndGet();
    _restColumnsController = _verticalLinkedControllers.addAndGet();
  }

  @override
  void dispose() {
    _headController.dispose();
    _horizontalBodyController.dispose();
    _restColumnsController.dispose();
    _firstColumnController.dispose();
    super.dispose();
  }

  List<Widget> _buildHeaderCells(ExpandableTableController data) => data
      .allHeaders
      .map(
        (e) => ExpandableTableCellWidget(
          height: data.headerHeight,
          width: e.width ?? data.defaultsColumnWidth,
          header: e,
          onTap: () {
            if (!e.disableDefaultOnTapExpansion) {
              e.toggleExpand();
            }
          },
          builder: e.cell.build,
        ),
      )
      .toList();

  Widget _buildRowCells(
    ExpandableTableController data,
    ExpandableTableRow row,
  ) {
    if (row.cells != null) {
      return Row(
        children: row.cells!
            .map(
              (cell) => ExpandableTableCellWidget(
                header: data.allHeaders[row.cells!.indexOf(cell)],
                row: row,
                height: row.height ?? data.defaultsRowHeight,
                width:
                    data.allHeaders[row.cells!.indexOf(cell)].width ??
                    data.defaultsColumnWidth,
                builder: cell.build,
              ),
            )
            .toList(),
      );
    } else {
      return ExpandableTableCellWidget(
        height: row.height ?? data.defaultsRowHeight,
        width: double.infinity,
        row: row,
        builder: (context, details) => row.legend!,
      );
    }
  }

  Widget _buildBody(ExpandableTableController data) => Row(
    children: [
      Builder(
        builder: (context) {
          final Widget child = ListView.builder(
            controller: _firstColumnController,
            physics: const ClampingScrollPhysics(),
            itemCount: data.allRows.length,
            itemBuilder: (context, index) => ListenableBuilder(
              listenable: data.allRows[index],
              builder: (context, child) => ExpandableTableCellWidget(
                row: data.allRows[index],
                height: data.allRows[index].height ?? data.defaultsRowHeight,
                width: data.firstColumnWidth,
                builder: data.allRows[index].firstCell.build,
                onTap: () {
                  if (!data.allRows[index].disableDefaultOnTapExpansion) {
                    data.allRows[index].toggleExpand();
                  }
                },
              ),
            ),
          );
          return SizedBox(
            width: data.firstColumnWidth,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ScrollShadow(
                size: data.scrollShadowSize,
                color: data.scrollShadowColor,
                fadeInCurve: data.scrollShadowFadeInCurve,
                fadeOutCurve: data.scrollShadowFadeOutCurve,
                duration: data.scrollShadowDuration,
                child: data.visibleScrollbar
                    ? Scrollbar(
                        controller: _firstColumnController,
                        thumbVisibility: data.thumbVisibilityScrollbar,
                        trackVisibility: data.trackVisibilityScrollbar,
                        scrollbarOrientation: ScrollbarOrientation.left,
                        child: child,
                      )
                    : child,
              ),
            ),
          );
        },
      ),
      Builder(
        builder: (context) {
          final Widget child = SingleChildScrollView(
            controller: _horizontalBodyController,
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: AnimatedCollapse(
              width: data.visibleHeadersWidth,
              duration: data.duration,
              curve: data.curve,
              child: ScrollShadow(
                size: data.scrollShadowSize,
                color: data.scrollShadowColor,
                fadeInCurve: data.scrollShadowFadeInCurve,
                fadeOutCurve: data.scrollShadowFadeOutCurve,
                duration: data.scrollShadowDuration,
                child: ListView.builder(
                  controller: _restColumnsController,
                  physics: const ClampingScrollPhysics(),
                  itemCount: data.allRows.length,
                  itemBuilder: (context, index) =>
                      _buildRowCells(data, data.allRows[index]),
                ),
              ),
            ),
          );

          return Expanded(
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(scrollbars: false),
              child: ScrollShadow(
                size: data.scrollShadowSize,
                color: data.scrollShadowColor,
                fadeInCurve: data.scrollShadowFadeInCurve,
                fadeOutCurve: data.scrollShadowFadeOutCurve,
                duration: data.scrollShadowDuration,
                child: data.visibleScrollbar
                    ? Scrollbar(
                        controller: _horizontalBodyController,
                        thumbVisibility: data.thumbVisibilityScrollbar,
                        trackVisibility: data.trackVisibilityScrollbar,
                        child: child,
                      )
                    : child,
              ),
            ),
          );
        },
      ),
    ],
  );

  double _computeTableWidth({required ExpandableTableController data}) =>
      data.firstColumnWidth +
      (data.headers
          .map(
            (e) =>
                (e.width ?? data.defaultsColumnWidth) +
                _computeChildrenWidth(
                  expandableTableHeader: e,
                  defaultsColumnWidth: data.defaultsColumnWidth,
                ),
          )
          .reduce((value, element) => value + element));

  double _computeTableHeight({required ExpandableTableController data}) =>
      data.headerHeight +
      (data.rows
          .map(
            (e) =>
                (e.height ?? data.defaultsRowHeight) +
                _computeChildrenHeight(
                  expandableTableRow: e,
                  defaultsRowHeight: data.defaultsRowHeight,
                ),
          )
          .reduce((value, element) => value + element));

  double _computeChildrenHeight({
    required ExpandableTableRow expandableTableRow,
    required double defaultsRowHeight,
  }) => expandableTableRow.childrenExpanded
      ? expandableTableRow.children!
            .map(
              (e) =>
                  (e.height ?? defaultsRowHeight) +
                  _computeChildrenHeight(
                    expandableTableRow: e,
                    defaultsRowHeight: defaultsRowHeight,
                  ),
            )
            .reduce((value, element) => value + element)
      : 0;

  double _computeChildrenWidth({
    required ExpandableTableHeader expandableTableHeader,
    required double defaultsColumnWidth,
  }) => expandableTableHeader.childrenExpanded
      ? expandableTableHeader.children!
            .map(
              (e) =>
                  (e.width ?? defaultsColumnWidth) +
                  _computeChildrenWidth(
                    expandableTableHeader: e,
                    defaultsColumnWidth: defaultsColumnWidth,
                  ),
            )
            .reduce((value, element) => value + element)
      : 0;

  @override
  Widget build(BuildContext context) {
    final ExpandableTableController data = ref.watch(
      expandableTableControllerProvider,
    );
    // Shadcn-themed scrollbars, mirroring the board.dart pattern; keeps the
    // Material defaults when no ShadTheme ancestor exists.
    final shadTheme = ShadTheme.maybeOf(context);
    final scrollbarTheme = shadTheme != null
        ? ScrollbarThemeData(
            thumbColor: WidgetStateProperty.all(
              shadTheme.colorScheme.primary.withAlpha(80),
            ),
            trackColor: WidgetStateProperty.all(
              shadTheme.colorScheme.background.withAlpha(0),
            ),
            thickness: WidgetStateProperty.all(6.0),
            radius: const Radius.circular(3.0),
          )
        : null;
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: scrollbarTheme ?? Theme.of(context).scrollbarTheme,
      ),
      child: ListenableBuilder(
        listenable: data,
        builder: (context, child) => SizedBox(
          width: data.expanded ? null : _computeTableWidth(data: data),
          height: data.expanded ? null : _computeTableHeight(data: data),
          child: Column(
            children: [
              SizedBox(
                height: data.headerHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double firstColWidth = min(
                      data.firstColumnWidth,
                      constraints.maxWidth * 0.6,
                    );
                    return Row(
                      children: [
                        SizedBox(
                          width: firstColWidth,
                          child: ExpandableTableCellWidget(
                            height: data.headerHeight,
                            width: firstColWidth,
                            builder: data.firstHeaderCell.build,
                          ),
                        ),
                        Expanded(
                          child: ScrollShadow(
                            size: data.scrollShadowSize,
                            color: data.scrollShadowColor,
                            fadeInCurve: data.scrollShadowFadeInCurve,
                            fadeOutCurve: data.scrollShadowFadeOutCurve,
                            duration: data.scrollShadowDuration,
                            child: ListView(
                              controller: _headController,
                              physics: const ClampingScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              children: _buildHeaderCells(data),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Expanded(child: _buildBody(data)),
            ],
          ),
        ),
      ),
    );
  }
}
