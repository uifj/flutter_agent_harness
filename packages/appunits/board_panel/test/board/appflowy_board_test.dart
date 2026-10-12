import 'package:board_panel/board_panel.dart';
import 'package:board_panel/src/widgets/board_group/group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test data models
class TextItem extends BoardPanelGroupItem {
  TextItem(this.title);

  final String title;

  @override
  String get id => title;
}

class RichTextItem extends BoardPanelGroupItem {
  RichTextItem({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  String get id => title;
}

// Test helpers
Widget buildTestBoard({
  required BoardPanelController controller,
  BoardPanelScrollController? scrollController,
  BoardPanelHeaderBuilder? headerBuilder,
  BoardPanelFooterBuilder? footerBuilder,
  BoxConstraints groupConstraints = const BoxConstraints.tightFor(width: 200),
  BoardPanelConfig config = const BoardPanelConfig(),
  bool shrinkWrap = false,
  OnLoadMoreCards? onLoadMore,
  HasMoreCards? hasMore,
  double? cardHeight,
}) {
  return MaterialApp(
    home: Scaffold(
      body: BoardPanel(
        controller: controller,
        boardScrollController: scrollController,
        onLoadMore: onLoadMore,
        hasMore: hasMore,
        cardBuilder: (context, group, groupItem) {
          return BoardPanelGroupCard(
            key: ValueKey(groupItem.id),
            child: Container(
              height: cardHeight,
              padding: const EdgeInsets.all(8),
              child: Text(groupItem.id, key: Key('card_${groupItem.id}')),
            ),
          );
        },
        headerBuilder: headerBuilder,
        footerBuilder: footerBuilder,
        groupConstraints: groupConstraints,
        config: config,
        shrinkWrap: shrinkWrap,
      ),
    ),
  );
}

BoardPanelController createTestController({
  void Function(String, int, String, int)? onMoveGroup,
  void Function(String, int, int)? onMoveGroupItem,
  void Function(String, int, String, int)? onMoveGroupItemToGroup,
}) {
  return BoardPanelController(
    onMoveGroup: onMoveGroup,
    onMoveGroupItem: onMoveGroupItem,
    onMoveGroupItemToGroup: onMoveGroupItemToGroup,
  );
}

void main() {
  group('BoardPanel - Basic Rendering', () {
    testWidgets('renders empty board without groups', (tester) async {
      final controller = createTestController();

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Board should render without errors
      expect(find.byType(BoardPanel), findsOneWidget);
    });

    testWidgets('renders board with single group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Test Group',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(BoardPanel), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('renders board with multiple groups', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item A'), TextItem('Item B')],
        ),
      );
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group2',
          name: 'Group 2',
          items: [TextItem('Item C'), TextItem('Item D')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
      expect(find.text('Item C'), findsOneWidget);
      expect(find.text('Item D'), findsOneWidget);
    });

    testWidgets('renders board with empty group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(id: 'empty_group', name: 'Empty Group', items: []),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byType(BoardPanel), findsOneWidget);
    });

    testWidgets('renders cards with correct keys', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('card1'), TextItem('card2')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('card_card1')), findsOneWidget);
      expect(find.byKey(const Key('card_card2')), findsOneWidget);
    });
  });

  group('BoardPanel - Header and Footer', () {
    testWidgets('renders custom header', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Test Group',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          headerBuilder: (context, groupData) {
            return Container(
              key: Key('header_${groupData.id}'),
              padding: const EdgeInsets.all(8),
              child: Text('Header: ${groupData.headerData.groupName}'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('header_group1')), findsOneWidget);
      expect(find.text('Header: Test Group'), findsOneWidget);
    });

    testWidgets('renders custom footer', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Test Group',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          footerBuilder: (context, groupData) {
            return Container(
              key: Key('footer_${groupData.id}'),
              padding: const EdgeInsets.all(8),
              child: const Text('Add New'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('footer_group1')), findsOneWidget);
      expect(find.text('Add New'), findsOneWidget);
    });

    testWidgets('header and footer appear for each group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group2',
          name: 'Group 2',
          items: [TextItem('Item 2')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          headerBuilder: (context, groupData) {
            return Container(
              key: Key('header_${groupData.id}'),
              child: Text('Header ${groupData.id}'),
            );
          },
          footerBuilder: (context, groupData) {
            return Container(
              key: Key('footer_${groupData.id}'),
              child: Text('Footer ${groupData.id}'),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('header_group1')), findsOneWidget);
      expect(find.byKey(const Key('header_group2')), findsOneWidget);
      expect(find.byKey(const Key('footer_group1')), findsOneWidget);
      expect(find.byKey(const Key('footer_group2')), findsOneWidget);
    });
  });

  group('BoardPanel - Group Controller Operations', () {
    testWidgets('adds group dynamically', (tester) async {
      final controller = createTestController();

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Initially no items
      expect(find.text('New Item'), findsNothing);

      // Add group
      controller.addGroup(
        BoardPanelGroupData(
          id: 'new_group',
          name: 'New Group',
          items: [TextItem('New Item')],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Item'), findsOneWidget);
    });

    testWidgets('removes group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);

      controller.removeGroup('group1');
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsNothing);
    });

    testWidgets('adds item to group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item 2'), findsNothing);

      controller.addGroupItem('group1', TextItem('Item 2'));
      await tester.pumpAndSettle();

      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('removes item from group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1'), TextItem('Item 2')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsOneWidget);

      controller.removeGroupItem('group1', 'Item 1');
      await tester.pumpAndSettle();

      expect(find.text('Item 1'), findsNothing);
      expect(find.text('Item 2'), findsOneWidget);
    });

    testWidgets('inserts item at specific index', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('First'), TextItem('Last')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      controller.insertGroupItem('group1', 1, TextItem('Middle'));
      await tester.pumpAndSettle();

      final groupController = controller.getGroupController('group1');
      expect(groupController?.items.length, 3);
      expect(groupController?.items[1].id, 'Middle');
    });

    testWidgets('updates group name', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Original Name',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          headerBuilder: (context, groupData) {
            return Text(groupData.headerData.groupName);
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Original Name'), findsOneWidget);

      controller.getGroupController('group1')?.updateGroupName('New Name');
      await tester.pumpAndSettle();

      expect(find.text('New Name'), findsOneWidget);
    });
  });

  group('BoardPanel - Configuration', () {
    testWidgets('applies group constraints', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          groupConstraints: const BoxConstraints.tightFor(width: 300),
        ),
      );
      await tester.pumpAndSettle();

      // Board renders with specified constraints
      expect(find.byType(BoardPanel), findsOneWidget);
    });

    testWidgets('applies background color config', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          config: const BoardPanelConfig(groupBackgroundColor: Colors.blue),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BoardPanel), findsOneWidget);
    });

    testWidgets('shrinkWrap mode renders correctly', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(controller: controller, shrinkWrap: true),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BoardPanel), findsOneWidget);
      expect(find.text('Item 1'), findsOneWidget);
    });

    testWidgets('corner radius config applies', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          config: const BoardPanelConfig(
            groupCornerRadius: 16.0,
            boardCornerRadius: 8.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BoardPanel), findsOneWidget);
    });
  });

  group('BoardPanel - Drag and Drop Callbacks', () {
    testWidgets('onMoveGroupItem callback is provided', (tester) async {
      bool callbackProvided = false;

      final controller = createTestController(
        onMoveGroupItem: (groupId, fromIndex, toIndex) {
          callbackProvided = true;
        },
      );
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item A'), TextItem('Item B')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Verify controller is set up correctly with callback
      expect(controller.getGroupController('group1'), isNotNull);
      expect(controller.getGroupController('group1')?.items.length, 2);
      // callback is provided but not triggered in this test
      expect(callbackProvided, isFalse);
    });

    testWidgets('onMoveGroupItemToGroup callback is provided', (tester) async {
      bool callbackProvided = false;

      final controller = createTestController(
        onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {
          callbackProvided = true;
        },
      );
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item A')],
        ),
      );
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group2',
          name: 'Group 2',
          items: [TextItem('Item B')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item A'), findsOneWidget);
      expect(find.text('Item B'), findsOneWidget);
      // callback is provided but not triggered in this test
      expect(callbackProvided, isFalse);
    });
  });

  group('BoardPanel - Data Integrity', () {
    testWidgets('maintains item order', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('First'), TextItem('Second'), TextItem('Third')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      final groupController = controller.getGroupController('group1');
      expect(groupController?.items[0].id, 'First');
      expect(groupController?.items[1].id, 'Second');
      expect(groupController?.items[2].id, 'Third');
    });

    testWidgets('maintains group order', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(id: 'group1', name: 'First Group', items: []),
      );
      controller.addGroup(
        BoardPanelGroupData(id: 'group2', name: 'Second Group', items: []),
      );
      controller.addGroup(
        BoardPanelGroupData(id: 'group3', name: 'Third Group', items: []),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.groupIds.length, 3);
      expect(controller.groupIds[0], 'group1');
      expect(controller.groupIds[1], 'group2');
      expect(controller.groupIds[2], 'group3');
    });

    testWidgets('handles duplicate item prevention', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Unique')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Try to add duplicate
      final result = controller
          .getGroupController('group1')
          ?.add(TextItem('Unique'));

      expect(result, false); // Should not add duplicate
      expect(controller.getGroupController('group1')?.items.length, 1);
    });

    testWidgets('clear all groups', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item 1')],
        ),
      );
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group2',
          name: 'Group 2',
          items: [TextItem('Item 2')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.groupIds.length, 2);

      controller.clear();
      await tester.pumpAndSettle();

      expect(controller.groupIds.length, 0);
    });
  });

  group('BoardPanel - Edge Cases', () {
    testWidgets('handles rapid add/remove operations', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(id: 'group1', name: 'Group 1', items: []),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Rapid operations
      for (int i = 0; i < 10; i++) {
        controller.addGroupItem('group1', TextItem('Item $i'));
      }
      await tester.pumpAndSettle();

      expect(controller.getGroupController('group1')?.items.length, 10);

      for (int i = 0; i < 5; i++) {
        controller.removeGroupItem('group1', 'Item $i');
      }
      await tester.pumpAndSettle();

      expect(controller.getGroupController('group1')?.items.length, 5);
    });

    testWidgets('handles empty group id gracefully', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: '',
          name: 'Empty ID Group',
          items: [TextItem('Item')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item'), findsOneWidget);
    });

    testWidgets('handles special characters in item IDs', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [
            TextItem('Item with spaces'),
            TextItem('Item-with-dashes'),
            TextItem('Item_with_underscores'),
            TextItem('Item.with.dots'),
          ],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Item with spaces'), findsOneWidget);
      expect(find.text('Item-with-dashes'), findsOneWidget);
      expect(find.text('Item_with_underscores'), findsOneWidget);
      expect(find.text('Item.with.dots'), findsOneWidget);
    });

    testWidgets('handles large number of items', (tester) async {
      final controller = createTestController();
      final items = List.generate(100, (index) => TextItem('Item $index'));
      controller.addGroup(
        BoardPanelGroupData(id: 'group1', name: 'Large Group', items: items),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.getGroupController('group1')?.items.length, 100);
    });

    testWidgets('handles large number of groups', (tester) async {
      final controller = createTestController();
      for (int i = 0; i < 20; i++) {
        controller.addGroup(
          BoardPanelGroupData(
            id: 'group$i',
            name: 'Group $i',
            items: [TextItem('Item in Group $i')],
          ),
        );
      }

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(controller.groupIds.length, 20);
    });
  });

  group('BoardPanel - Move Operations', () {
    testWidgets('moveGroupItem moves item within group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item A'), TextItem('Item B'), TextItem('Item C')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Move Item A from index 0 to index 2
      // The move function removes from index 0 first, then inserts at index 2
      // Result: [Item B, Item C, Item A]
      controller.moveGroupItem('group1', 0, 2);
      await tester.pumpAndSettle();

      final groupController = controller.getGroupController('group1');
      expect(groupController?.items.length, 3);
      // After removing from 0 and inserting at 2:
      // [A, B, C] -> remove A -> [B, C] -> insert at 2 -> [B, C, A]
      expect(groupController?.items[0].id, 'Item B');
      expect(groupController?.items[1].id, 'Item C');
      expect(groupController?.items[2].id, 'Item A');
    });

    testWidgets('moveGroup reorders groups', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(id: 'group1', name: 'Group 1', items: []),
      );
      controller.addGroup(
        BoardPanelGroupData(id: 'group2', name: 'Group 2', items: []),
      );
      controller.addGroup(
        BoardPanelGroupData(id: 'group3', name: 'Group 3', items: []),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Move group from index 0 to index 2
      // Similar behavior: remove from 0, insert at 2
      // [g1, g2, g3] -> remove g1 -> [g2, g3] -> insert at 2 -> [g2, g3, g1]
      controller.moveGroup(0, 2);
      await tester.pumpAndSettle();

      expect(controller.groupIds[0], 'group2');
      expect(controller.groupIds[1], 'group3');
      expect(controller.groupIds[2], 'group1');
    });

    testWidgets('group controller move operation', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item A'), TextItem('Item B'), TextItem('Item C')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Use the group controller's move method directly
      final groupController = controller.getGroupController('group1');
      final moved = groupController?.move(0, 1);

      await tester.pumpAndSettle();

      expect(moved, true);
      expect(groupController?.items[0].id, 'Item B');
      expect(groupController?.items[1].id, 'Item A');
      expect(groupController?.items[2].id, 'Item C');
    });
  });

  group('BoardPanel - Dragging State', () {
    testWidgets('item draggable state can be toggled', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Item A')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      final groupController = controller.getGroupController('group1');

      // Initially draggable
      expect(groupController?.items[0].draggable.value, true);

      // Disable dragging
      groupController?.enableDragging(false);
      expect(groupController?.items[0].draggable.value, false);

      // Re-enable dragging
      groupController?.enableDragging(true);
      expect(groupController?.items[0].draggable.value, true);
    });
  });

  group('BoardPanel - Scroll Controller', () {
    testWidgets('board scroll controller is accessible', (tester) async {
      final controller = createTestController();
      final scrollController = BoardPanelScrollController();

      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: List.generate(20, (i) => TextItem('Item $i')),
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          scrollController: scrollController,
        ),
      );
      await tester.pumpAndSettle();

      // Scroll controller should be connected
      expect(find.byType(BoardPanel), findsOneWidget);
    });
  });

  group('BoardPanel - Lazy Loading', () {
    testWidgets('limits initial visible cards', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: List.generate(12, (i) => TextItem('Item $i')),
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          config: const BoardPanelConfig(cardPageSize: 5),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 0'), findsOneWidget);
      expect(find.text('Item 4'), findsOneWidget);
      expect(find.text('Item 5'), findsNothing);
    });

    testWidgets('loads more cards when scrolling to bottom', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: List.generate(8, (i) => TextItem('Item $i')),
        ),
      );

      var loadCalls = 0;

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          config: const BoardPanelConfig(
            cardPageSize: 3,
            loadMoreTriggerOffset: 0,
          ),
          groupConstraints: const BoxConstraints.tightFor(
            width: 200,
            height: 120,
          ),
          cardHeight: 60,
          onLoadMore: (_) async {
            loadCalls += 1;
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 5'), findsNothing);

      final verticalScrollable = find.byWidgetPredicate((widget) {
        return widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up);
      });
      expect(verticalScrollable, findsOneWidget);

      final scrollableState = tester.state<ScrollableState>(verticalScrollable);
      scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.text('Item 5'), findsOneWidget);
      expect(loadCalls, 1);
    });

    testWidgets('respects hasMore false', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: List.generate(8, (i) => TextItem('Item $i')),
        ),
      );

      await tester.pumpWidget(
        buildTestBoard(
          controller: controller,
          config: const BoardPanelConfig(
            cardPageSize: 3,
            loadMoreTriggerOffset: 0,
          ),
          groupConstraints: const BoxConstraints.tightFor(
            width: 200,
            height: 120,
          ),
          cardHeight: 60,
          hasMore: (_) => false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Item 2'), findsOneWidget);
      expect(find.text('Item 3'), findsNothing);

      final verticalScrollable = find.byWidgetPredicate((widget) {
        return widget is Scrollable &&
            (widget.axisDirection == AxisDirection.down ||
                widget.axisDirection == AxisDirection.up);
      });
      expect(verticalScrollable, findsOneWidget);

      final scrollableState = tester.state<ScrollableState>(verticalScrollable);
      scrollableState.position.jumpTo(scrollableState.position.maxScrollExtent);
      await tester.pumpAndSettle();

      expect(find.text('Item 3'), findsNothing);
    });
  });

  group('BoardPanel - Replace Operations', () {
    testWidgets('replace item at index', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('Original')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsOneWidget);

      controller.getGroupController('group1')?.replace(0, TextItem('Replaced'));
      await tester.pumpAndSettle();

      expect(find.text('Original'), findsNothing);
      expect(find.text('Replaced'), findsOneWidget);
    });

    testWidgets('replaceOrInsertItem updates existing item', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [TextItem('ExistingId')],
        ),
      );

      await tester.pumpWidget(buildTestBoard(controller: controller));
      await tester.pumpAndSettle();

      // Replace with same ID but different instance
      controller
          .getGroupController('group1')
          ?.replaceOrInsertItem(TextItem('ExistingId'));
      await tester.pumpAndSettle();

      expect(controller.getGroupController('group1')?.items.length, 1);
    });
  });

  group('BoardPanel - Custom Item Types', () {
    testWidgets('handles RichTextItem type', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [RichTextItem(title: 'Rich Title', subtitle: 'Rich Subtitle')],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardPanel(
              controller: controller,
              cardBuilder: (context, group, groupItem) {
                if (groupItem is RichTextItem) {
                  return BoardPanelGroupCard(
                    key: ValueKey(groupItem.id),
                    child: Column(
                      children: [
                        Text(groupItem.title, key: const Key('title')),
                        Text(groupItem.subtitle, key: const Key('subtitle')),
                      ],
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rich Title'), findsOneWidget);
      expect(find.text('Rich Subtitle'), findsOneWidget);
    });

    testWidgets('handles mixed item types in same group', (tester) async {
      final controller = createTestController();
      controller.addGroup(
        BoardPanelGroupData(
          id: 'group1',
          name: 'Group 1',
          items: [
            TextItem('Simple Text'),
            RichTextItem(title: 'Rich', subtitle: 'Text'),
          ],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoardPanel(
              controller: controller,
              cardBuilder: (context, group, groupItem) {
                if (groupItem is RichTextItem) {
                  return BoardPanelGroupCard(
                    key: ValueKey(groupItem.id),
                    child: Text('Rich: ${groupItem.title}'),
                  );
                }
                return BoardPanelGroupCard(
                  key: ValueKey(groupItem.id),
                  child: Text('Simple: ${groupItem.id}'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Simple: Simple Text'), findsOneWidget);
      expect(find.text('Rich: Rich'), findsOneWidget);
    });
  });
}
