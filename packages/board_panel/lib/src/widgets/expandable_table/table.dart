// Flutter imports:
import 'package:flutter/material.dart';
// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

import './class/controller.dart';
import './class/header.dart';
import './class/row.dart';
import './widget_internal/table.dart';
// Project imports:
import 'class/cell.dart';

/// Ambient access to the [ExpandableTableController] for the internal
/// table widgets.
///
/// Injected by [ExpandableTable] through a scoped [ProviderScope] override;
/// reading it outside of an [ExpandableTable] subtree is a usage error.
final expandableTableControllerProvider = Provider<ExpandableTableController>(
  (ref) => throw UnimplementedError(
    'expandableTableControllerProvider must be overridden by ExpandableTable',
  ),
);

/// [ExpandableTable] class.
class ExpandableTable extends StatefulWidget {
  /// [firstHeaderCell] is the top left cell, i.e. the first header cell.
  /// Not to be used if the [controller] is used.
  /// `optional`
  final ExpandableTableCell? firstHeaderCell;

  /// [headers] contains the list of all column headers,
  /// each one of these can contain a list of further headers,
  /// this allows you to create nested and expandable columns.
  /// Not to be used if the [controller] is used.
  /// `optional`
  final List<ExpandableTableHeader>? headers;

  /// [rows] contains the list of all the rows of the table,
  /// each of these can contain a list of further rows,
  /// this allows you to create nested and expandable rows.
  /// Not to be used if the [controller] is used.
  /// `optional`
  final List<ExpandableTableRow>? rows;

  /// [headerHeight] is the height of each column header, i.e. the first row.
  /// `Default: 188`
  final double headerHeight;

  /// [firstColumnWidth] determines first Column width size.
  ///
  /// Default: [200]
  final double firstColumnWidth;

  /// [defaultsColumnWidth] defines the default width of all columns,
  /// it is possible to redefine it for each individual column.
  /// Default: [120]
  final double defaultsColumnWidth;

  /// [defaultsRowHeight] defines the default height of all rows,
  /// it is possible to redefine it for every single row.
  /// Default: [50]
  final double defaultsRowHeight;

  /// [duration] determines duration rendered animation of Rows/Columns expansion.
  ///
  /// Default: [500ms]
  final Duration duration;

  /// [curve] determines rendered curve animation of Rows/Columns expansion.
  ///
  /// Default: [Curves.fastOutSlowIn]
  final Curve curve;

  /// [scrollShadowDuration] determines duration rendered animation of shadows.
  ///
  /// Default: [500ms]
  final Duration scrollShadowDuration;

  /// [scrollShadowCurve] determines rendered curve animation of shadows.
  ///
  /// Default: [Curves.fastOutSlowIn]
  final Curve scrollShadowCurve;

  /// [scrollShadowColor] determines rendered color of shadows.
  ///
  /// Default: [Colors.transparent]
  final Color scrollShadowColor;

  /// [scrollShadowSize] determines size of shadows.
  ///
  /// Default: [10]
  final double scrollShadowSize;

  /// [visibleScrollbar] determines visibility of horizontal and vertical scrollbars.
  ///
  /// Default: [false]
  final bool visibleScrollbar;

  /// [trackVisibilityScrollbar] indicates that the scrollbar track should be visible.
  ///
  /// 'optional'
  final bool? trackVisibilityScrollbar;

  /// [thumbVisibilityScrollbar] indicates that the scrollbar thumb should be visible, even when a scroll is not underway.
  ///
  /// 'optional'
  final bool? thumbVisibilityScrollbar;

  /// [expanded] indicates that the table expands, so it fills the available space along the horizontal and vertical axes.
  ///
  /// Default: [true]
  final bool expanded;

  /// [controller] specifies the external controller of the table, allows
  /// you to dynamically manage the data in the table externally.
  /// Do not use if [firstHeaderCell], [headers] and [rows] are passed
  /// 'optional'
  final ExpandableTableController? controller;

  /// [ExpandableTable] class constructor.
  /// Required:
  ///   - [firstHeaderCell]
  ///   - [rows]
  ///   - [headers]
  /// ```dart
  ///      return ExpandableTable(
  ///       firstHeaderCell: ExpandableTableCell(
  ///         child: Text('Simple\nTable'),
  ///       ),
  ///       headers: headers,
  ///       rows: rows,
  ///     );
  /// ```
  const ExpandableTable({
    super.key,
    this.firstHeaderCell,
    this.headers,
    this.rows,
    this.controller,
    this.headerHeight = 188,
    this.firstColumnWidth = 200,
    this.defaultsColumnWidth = 120,
    this.defaultsRowHeight = 50,
    this.duration = const Duration(milliseconds: 500),
    this.curve = Curves.fastOutSlowIn,
    this.scrollShadowDuration = const Duration(milliseconds: 500),
    this.scrollShadowCurve = Curves.fastOutSlowIn,
    this.scrollShadowColor = Colors.transparent,
    this.scrollShadowSize = 10,
    this.visibleScrollbar = false,
    this.trackVisibilityScrollbar,
    this.thumbVisibilityScrollbar,
    this.expanded = true,
  }) : assert(
         ((firstHeaderCell != null && rows != null && headers != null) ||
                 controller != null) &&
             !(thumbVisibilityScrollbar == false &&
                 (trackVisibilityScrollbar ?? false)),
       );

  @override
  State<ExpandableTable> createState() => _ExpandableTableState();
}

class _ExpandableTableState extends State<ExpandableTable> {
  /// Controller created internally when [ExpandableTable.controller] is not
  /// provided. Owned (and disposed) by this state.
  ExpandableTableController? _internalController;

  ExpandableTableController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    if (widget.controller == null) {
      final int totalColumns = widget.headers!
          .map((e) => e.columnsCount)
          .fold(0, (a, b) => a + b);
      for (int i = 0; i < widget.rows!.length; i++) {
        if (widget.rows![i].cellsCount != null &&
            widget.rows![i].cellsCount != totalColumns) {
          throw FormatException(
            'Row $i cells count ${widget.rows![i].cellsCount} <> $totalColumns header cell count.',
          );
        }
      }
      _internalController = _createController();
    }
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ExpandableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (widget.controller != null) {
        _internalController?.dispose();
        _internalController = null;
      } else {
        _internalController ??= _createController();
      }
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  ExpandableTableController _createController() => ExpandableTableController(
    firstHeaderCell: widget.firstHeaderCell!,
    headers: widget.headers!,
    rows: widget.rows!,
    duration: widget.duration,
    curve: widget.curve,
    scrollShadowDuration: widget.scrollShadowDuration,
    scrollShadowFadeInCurve: widget.scrollShadowCurve,
    scrollShadowFadeOutCurve: widget.scrollShadowCurve,
    scrollShadowColor: widget.scrollShadowColor,
    scrollShadowSize: widget.scrollShadowSize,
    firstColumnWidth: widget.firstColumnWidth,
    defaultsColumnWidth: widget.defaultsColumnWidth,
    defaultsRowHeight: widget.defaultsRowHeight,
    headerHeight: widget.headerHeight,
    visibleScrollbar: widget.visibleScrollbar,
    trackVisibilityScrollbar: widget.trackVisibilityScrollbar,
    thumbVisibilityScrollbar: widget.thumbVisibilityScrollbar,
    expanded: widget.expanded,
  );

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;
    return ProviderScope(
      // Re-key the scope when the controller instance changes so that the
      // override is rebuilt instead of mutated on the fly.
      key: ObjectKey(controller),
      overrides: [
        expandableTableControllerProvider.overrideWith((ref) => controller),
      ],
      child: const InternalTable(),
    );
  }
}
