import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:board_panel/board_panel.dart';

class SingleBoardListExample extends StatefulWidget {
  const SingleBoardListExample({super.key});

  @override
  State<SingleBoardListExample> createState() =>
      _SingleBoardListExampleState();
}

class _SingleBoardListExampleState extends State<SingleBoardListExample> {
  final BoardPanelController boardData = BoardPanelController();

  @override
  void initState() {
    super.initState();
    boardData.addGroup(BoardPanelGroupData(
      id: 'column-1',
      name: 'Single Column',
      items: [
        SingleItem('a', 'Item A'),
        SingleItem('b', 'Item B'),
        SingleItem('c', 'Item C'),
        SingleItem('d', 'Item D'),
        SingleItem('e', 'Item E'),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return BoardPanel(
      controller: boardData,
      cardBuilder: (context, column, columnItem) {
        final item = columnItem as SingleItem;
        return BoardPanelGroupCard(
          key: ValueKey(item.id),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(item.title, style: theme.textTheme.p),
          ),
        );
      },
      headerBuilder: (context, columnData) {
        return BoardPanelGroupHeader(
          title: Text(
            columnData.headerData.groupName,
            style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.w600),
          ),
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 12),
        );
      },
      groupConstraints: const BoxConstraints(maxWidth: 360),
      config: BoardPanelConfig(
        groupBackgroundColor: theme.colorScheme.muted,
        stretchGroupHeight: false,
      ),
    );
  }
}

class SingleItem extends BoardPanelGroupItem {
  final String title;

  SingleItem(String id, this.title) : _id = id;

  final String _id;

  @override
  String get id => _id;
}
