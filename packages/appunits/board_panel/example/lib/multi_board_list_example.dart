import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:board_panel/board_panel.dart';

class MultiBoardListExample extends StatefulWidget {
  const MultiBoardListExample({super.key});

  @override
  State<MultiBoardListExample> createState() => _MultiBoardListExampleState();
}

class _MultiBoardListExampleState extends State<MultiBoardListExample> {
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
      id: 'todo',
      name: 'To Do',
      items: [
        for (int i = 1; i <= 30; i++) KanbanItem('todo-$i', 'Task $i'),
      ],
    ));

    controller.addGroup(BoardPanelGroupData(
      id: 'in_progress',
      name: 'In Progress',
      items: [
        for (int i = 1; i <= 20; i++)
          KanbanItem('progress-$i', 'Development $i'),
      ],
    ));

    controller.addGroup(BoardPanelGroupData(
      id: 'review',
      name: 'Review',
      items: [
        for (int i = 1; i <= 15; i++)
          KanbanItem('review-$i', 'PR Review $i'),
      ],
    ));

    controller.addGroup(BoardPanelGroupData(
      id: 'done',
      name: 'Done',
      items: [
        for (int i = 1; i <= 25; i++)
          KanbanItem('done-$i', 'Completed $i'),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    final config = BoardPanelConfig(
      groupBackgroundColor: theme.colorScheme.muted,
      stretchGroupHeight: false,
      cardPageSize: 10,
      responsiveGroupConstraints: ResponsiveGroupConstraints(
        defaultConstraints: const BoxConstraints(maxWidth: 240),
        sm: const BoxConstraints(maxWidth: 200),
        md: const BoxConstraints(maxWidth: 220),
        lg: const BoxConstraints(maxWidth: 260),
        xl: const BoxConstraints(maxWidth: 290),
        xxl: const BoxConstraints(maxWidth: 320),
      ),
    );

    return BoardPanel(
      controller: controller,
      cardBuilder: (context, group, groupItem) {
        final item = groupItem as KanbanItem;
        return BoardPanelGroupCard(
          key: ValueKey(groupItem.id),
          child: _KanbanCard(item: item),
        );
      },
      onLoadMore: (groupData) async {
        await Future.delayed(const Duration(milliseconds: 500));
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
          moreIcon: const Icon(LucideIcons.ellipsis, size: 18),
          addIcon: const Icon(LucideIcons.plus, size: 18),
          height: 48,
          margin: config.groupBodyPadding,
          onAddButtonClick: () {
            final groupController =
                controller.getGroupController(columnData.id);
            if (groupController != null) {
              final count = groupController.items.length + 1;
              groupController.add(KanbanItem(
                '${columnData.id}-new-$count',
                'New Card $count',
              ));
            }
          },
        );
      },
      footerBuilder: (context, columnData) {
        return BoardPanelGroupFooter(
          icon: const Icon(LucideIcons.plus, size: 18),
          title: const Text('Add card'),
          height: 48,
          margin: config.groupBodyPadding,
          onAddButtonClick: () {
            boardController.scrollToBottom(columnData.id);
          },
        );
      },
      groupConstraints: const BoxConstraints(maxWidth: 240),
      config: config,
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({required this.item});

  final KanbanItem item;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            style: theme.textTheme.p,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                LucideIcons.messageCircle,
                size: 14,
                color: theme.colorScheme.mutedForeground,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.id.hashCode % 5}',
                style: theme.textTheme.small.copyWith(
                  color: theme.colorScheme.mutedForeground,
                ),
              ),
              const Spacer(),
              ShadBadge.secondary(
                child: Text(
                  _priorityLabel(item.id.hashCode % 3),
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 0:
        return 'Low';
      case 1:
        return 'Medium';
      default:
        return 'High';
    }
  }
}

class KanbanItem extends BoardPanelGroupItem {
  final String title;

  KanbanItem(String id, this.title) : _id = id;

  final String _id;

  @override
  String get id => _id;
}
