import 'package:flutter/material.dart';
import 'package:board_panel/board_panel.dart';

const _primaryColor = Color(0xFF1e2f36);
const _accentColor = Color(0xFF0d2026);
const _textStyle = TextStyle(color: Colors.white);

class ExpandableTableDemoPage extends StatelessWidget {
  const ExpandableTableDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
            '   Simple Table                    |                    Expandable Table'),
        centerTitle: true,
      ),
      body: Container(
        color: _accentColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildSimpleTable(),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: _buildExpandableTable(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ExpandableTable _buildSimpleTable() {
    const int columnsCount = 20;
    const int rowsCount = 20;
    final List<ExpandableTableHeader> headers = List.generate(
      columnsCount - 1,
      (index) => ExpandableTableHeader(
        width: index % 2 == 0 ? 200 : 150,
        cell: _buildCell('Column $index'),
      ),
    );
    final List<ExpandableTableRow> rows = List.generate(
      rowsCount,
      (rowIndex) => ExpandableTableRow(
        height: rowIndex % 2 == 0 ? 50 : 70,
        firstCell: _buildCell('Row $rowIndex'),
        cells: List<ExpandableTableCell>.generate(
          columnsCount - 1,
          (columnIndex) => _buildCell('Cell $rowIndex:$columnIndex'),
        ),
      ),
    );

    return ExpandableTable(
      firstHeaderCell: _buildCell('Simple\nTable'),
      headers: headers,
      scrollShadowColor: _accentColor,
      rows: rows,
      visibleScrollbar: true,
      trackVisibilityScrollbar: true,
      thumbVisibilityScrollbar: true,
    );
  }

  ExpandableTable _buildExpandableTable() {
    const int columnsCount = 20;
    const int subColumnsCount = 2;
    const int rowsCount = 6;
    const int subRowsCount = 3;

    final List<ExpandableTableHeader> subHeader = List.generate(
      subColumnsCount,
      (index) => ExpandableTableHeader(
        cell: _buildCell('Sub Column $index'),
      ),
    );

    final List<ExpandableTableHeader> headers = List.generate(
      columnsCount,
      (index) => ExpandableTableHeader(
          cell: _buildCell(
              '${index == 1 ? 'Expandable\nColumn' : 'Column'} $index'),
          children: index == 1 ? subHeader : null),
    );

    return ExpandableTable(
      firstHeaderCell: _buildCell('Expandable\nTable'),
      rows: _generateRows(rowsCount, subRowsCount: subRowsCount,
          totalColumns: columnsCount + subColumnsCount),
      headers: headers,
      defaultsRowHeight: 60,
      defaultsColumnWidth: 150,
      firstColumnWidth: 250,
      scrollShadowColor: _accentColor,
      visibleScrollbar: true,
      expanded: false,
    );
  }

  List<ExpandableTableRow> _generateRows(
    int quantity, {
    required int subRowsCount,
    required int totalColumns,
    int depth = 0,
  }) {
    final bool generateLegendRow = (depth == 0 || depth == 2);
    return List.generate(
      quantity,
      (rowIndex) => ExpandableTableRow(
        firstCell: _buildFirstRowCell(),
        children: ((rowIndex == 3 || rowIndex == 2) && depth < 3)
            ? _generateRows(subRowsCount,
                subRowsCount: subRowsCount,
                totalColumns: totalColumns,
                depth: depth + 1)
            : null,
        cells: !(generateLegendRow && (rowIndex == 3 || rowIndex == 2))
            ? List<ExpandableTableCell>.generate(
                totalColumns,
                (columnIndex) => _buildCell('Cell $rowIndex:$columnIndex'),
              )
            : null,
        legend: generateLegendRow && (rowIndex == 3 || rowIndex == 2)
            ? const _DefaultCellCard(
                child: Align(
                  alignment: FractionalOffset.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 24.0),
                    child: Text(
                      'This is row legend',
                      style: _textStyle,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  ExpandableTableCell _buildCell(String content, {CellBuilder? builder}) =>
      ExpandableTableCell(
        child: builder != null
            ? null
            : _DefaultCellCard(
                child: Center(
                  child: Text(
                    content,
                    style: _textStyle,
                  ),
                ),
              ),
        builder: builder,
      );

  ExpandableTableCell _buildFirstRowCell() => ExpandableTableCell(
        builder: (context, details) => _DefaultCellCard(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0),
            child: Row(
              children: [
                SizedBox(
                  width: 24 * details.row!.address.length.toDouble(),
                  child: details.row?.children != null
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 500),
                            turns: details.row?.childrenExpanded == true
                                ? 0.25
                                : 0,
                            child: const Icon(
                              Icons.keyboard_arrow_right,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : null,
                ),
                Text(
                  '${details.row!.address.length > 1 ? details.row!.address.skip(1).map((e) => 'Sub ').join() : ''}Row ${details.row!.address.last}',
                  style: _textStyle,
                ),
              ],
            ),
          ),
        ),
      );
}

class _DefaultCellCard extends StatelessWidget {
  const _DefaultCellCard({this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _primaryColor,
        border: Border.all(color: _accentColor, width: 1.0),
      ),
      child: child,
    );
  }
}
