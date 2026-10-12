// Flutter imports:
import 'package:flutter/material.dart';
// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../../board_panel.dart';
import '../widget_internal/animated_container.dart';

/// [ExpandableTableCellWidget] it is the widget that builds the table cell.
class ExpandableTableCellWidget extends ConsumerWidget {
  /// [builder] method for building cell content.
  final Widget Function(BuildContext context, CellDetails details) builder;

  /// [height] cell height.
  final double height;

  /// [width] cell width.
  final double width;

  /// [onTap] tap event.
  final VoidCallback? onTap;

  /// [header] header of the table this cell belongs to.
  final ExpandableTableHeader? header;

  /// [row] row of the table this cell belongs to.
  final ExpandableTableRow? row;

  /// [ExpandableTableCellWidget] widget constructor.
  const ExpandableTableCellWidget({
    super.key,
    required this.builder,
    required this.height,
    required this.width,
    this.onTap,
    this.header,
    this.row,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // duration/curve are final fields of the controller; the provider value
    // itself never changes, so this watch does not trigger extra rebuilds.
    final controller = ref.watch(expandableTableControllerProvider);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedCollapse(
        duration: controller.duration,
        curve: controller.curve,
        width: header?.visible == false ? 0 : width,
        height: row?.visible == false ? 0 : height,
        child: builder(
          context,
          CellDetails(
            headerParent: header?.parent,
            rowParent: row?.parent,
            header: header,
            row: row,
          ),
        ),
      ),
    );
  }
}
