import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:board_panel/board_panel.dart';

class MultiBoardShrinkwrapListExample extends StatefulWidget {
  const MultiBoardShrinkwrapListExample({super.key});

  @override
  State<MultiBoardShrinkwrapListExample> createState() =>
      _MultiBoardShrinkwrapListExampleState();
}

class _MultiBoardShrinkwrapListExampleState
    extends State<MultiBoardShrinkwrapListExample> {
  final BoardPanelController controller = BoardPanelController(
    onMoveGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
      debugPrint('Move group $fromGroupId:$fromIndex -> $toGroupId:$toIndex');
    },
    onMoveGroupItem: (groupId, fromIndex, toIndex) {
      debugPrint('Move $groupId:$fromIndex -> $groupId:$toIndex');
    },
    onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
      debugPrint('Cross move $fromGroupId:$fromIndex -> $toGroupId:$toIndex');
    },
  );

  late BoardPanelScrollController boardController;

  @override
  void initState() {
    super.initState();
    boardController = BoardPanelScrollController();

    controller.addGroup(BoardPanelGroupData(
      id: 'backlog',
      name: 'Backlog',
      items: [
        ShrinkItem('b-1', 'Research competitors'),
        ShrinkItem('b-2', 'Write user stories'),
        ShrinkItem('b-3', 'Design wireframes'),
        ShrinkItem('b-4', 'Setup CI/CD pipeline'),
      ],
    ));

    controller.addGroup(BoardPanelGroupData(
      id: 'sprint',
      name: 'Current Sprint',
      items: [
        ShrinkItem('s-1', 'Implement login flow'),
        ShrinkItem('s-2', 'Build dashboard UI'),
        ShrinkItem('s-3', 'API integration'),
      ],
    ));

    controller.addGroup(BoardPanelGroupData(
      id: 'testing',
      name: 'Testing',
      items: [
        ShrinkItem('t-1', 'Write unit tests'),
        ShrinkItem('t-2', 'Manual QA pass'),
        ShrinkItem('t-3', 'Performance testing'),
      ],
    ));

    controller.addGroup(BoardPanelGroupData(
      id: 'released',
      name: 'Released',
      items: [
        ShrinkItem('r-1', 'v1.0 Release notes'),
        ShrinkItem('r-2', 'Customer feedback'),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final config = BoardPanelConfig(
      groupBackgroundColor: theme.colorScheme.muted,
      stretchGroupHeight: false,
    );

    return SingleChildScrollView(
      child: BoardPanel(
        controller: controller,
        shrinkWrap: true,
        cardBuilder: (context, group, groupItem) {
          final item = groupItem as ShrinkItem;
          return BoardPanelGroupCard(
            key: ValueKey(groupItem.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(item.title, style: theme.textTheme.p),
            ),
          );
        },
        boardScrollController: boardController,
        headerBuilder: (context, columnData) {
          return BoardPanelGroupHeader(
            title: Expanded(
              child: Text(
                columnData.headerData.groupName,
                style: theme.textTheme.h4.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            addIcon: const Icon(LucideIcons.plus, size: 18),
            height: 48,
            margin: config.groupBodyPadding,
            onAddButtonClick: () {
              final groupController =
                  controller.getGroupController(columnData.id);
              if (groupController != null) {
                final count = groupController.items.length + 1;
                groupController.add(ShrinkItem(
                  '${columnData.id}-new-$count',
                  'New Item $count',
                ));
              }
            },
          );
        },
        footerBuilder: (context, columnData) {
          return BoardPanelGroupFooter(
            icon: const Icon(LucideIcons.plus, size: 18),
            title: const Text('Add item'),
            height: 48,
            margin: config.groupBodyPadding,
            onAddButtonClick: () {
              boardController.scrollToBottom(columnData.id);
            },
          );
        },
        groupConstraints: const BoxConstraints.tightFor(width: 240),
        config: config,
        responsiveGroupConstraints: ResponsiveGroupConstraints(
          defaultConstraints: const BoxConstraints.tightFor(width: 240),
          sm: const BoxConstraints.tightFor(width: 200),
          md: const BoxConstraints.tightFor(width: 220),
          lg: const BoxConstraints.tightFor(width: 260),
          xl: const BoxConstraints.tightFor(width: 290),
          xxl: const BoxConstraints.tightFor(width: 320),
        ),
      ),
    );
  }
}

class ShrinkItem extends BoardPanelGroupItem {
  final String title;

  ShrinkItem(String id, this.title) : _id = id;

  final String _id;

  @override
  String get id => _id;
}
