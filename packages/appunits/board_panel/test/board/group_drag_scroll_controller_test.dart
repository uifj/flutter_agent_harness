/// Regression tests for the group (column) drag crash.
///
/// Dragging a whole column used to throw
/// `ScrollController attached to multiple scroll views`: the board hoisted one
/// `ScrollController` per group id and injected it into the column widget,
/// while `Draggable` mounts that very same column widget again as the drag
/// feedback (and once more as `childWhenDragging`). Two live scroll views then
/// shared one controller and `ScrollController.position`'s
/// `_positions.length == 1` assertion fired on every pointer move.
library;

import 'package:board_panel/board_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item extends BoardPanelGroupItem {
  _Item(this.title);

  final String title;

  @override
  String get id => title;
}

BoardPanelGroupData<dynamic> _group(String id, int cardCount) =>
    BoardPanelGroupData<dynamic>(
      id: id,
      name: id,
      items: [for (var i = 0; i < cardCount; i++) _Item('$id-$i')],
    );

Widget _board(BoardPanelController controller) => MaterialApp(
  home: Scaffold(
    body: BoardPanel(
      controller: controller,
      groupConstraints: const BoxConstraints.tightFor(width: 200),
      cardBuilder: (context, group, item) => BoardPanelGroupCard(
        key: ValueKey(item.id),
        child: SizedBox(height: 60, child: Text(item.id)),
      ),
      headerBuilder: (context, group) => BoardPanelGroupHeader(
        height: 40,
        title: Text(group.headerData.groupName),
      ),
    ),
  ),
);

void main() {
  group('group drag does not share a ScrollController', () {
    testWidgets('dragging a column raises no assertion', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = BoardPanelController(
        // Column reordering is opted into, so the columns stay draggable and
        // the feedback copy of a column really does get mounted.
        onMoveGroup: (_, _, _, _) {},
      )..addGroups([_group('todo', 6), _group('doing', 6), _group('done', 6)]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_board(controller));
      await tester.pumpAndSettle();

      // Grab the first column by its header and drag it across the board,
      // holding the gesture so the feedback subtree stays mounted while more
      // pointer moves are routed.
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('todo')),
      );
      await tester.pump(const Duration(milliseconds: 600));

      for (var i = 0; i < 6; i++) {
        await gesture.moveBy(const Offset(60, 0));
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester.takeException(),
          isNull,
          reason: 'pointer move $i must not trip a ScrollController assertion',
        );
      }

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('each column keeps an independent scroll position', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controller = BoardPanelController()
        ..addGroups([_group('todo', 12), _group('doing', 12)]);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_board(controller));
      await tester.pumpAndSettle();

      // Scrolling one column must not move the other: the controllers are now
      // owned per group state instead of being handed out by the board.
      await tester.drag(find.text('todo-0'), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('doing-0'), findsOneWidget);
    });
  });

  group('group draggability follows onMoveGroup', () {
    test('columns are not draggable when the host cannot persist the move', () {
      final controller = BoardPanelController()
        ..addGroups([_group('todo', 1), _group('doing', 1)]);
      addTearDown(controller.dispose);

      for (final group in controller.groupDatas) {
        expect(
          group.draggable.value,
          isFalse,
          reason: 'a column drag would have nowhere to be written back to',
        );
      }
    });

    test('columns are draggable once onMoveGroup is registered', () {
      final controller = BoardPanelController(onMoveGroup: (_, _, _, _) {})
        ..addGroups([_group('todo', 1)]);
      addTearDown(controller.dispose);

      expect(controller.groupDatas.single.draggable.value, isTrue);
    });

    test('insertGroup applies the same rule', () {
      final controller = BoardPanelController()
        ..insertGroup(0, _group('todo', 1));
      addTearDown(controller.dispose);

      expect(controller.groupDatas.single.draggable.value, isFalse);
    });

    test('enableGroupDragging still overrides the default', () {
      final controller = BoardPanelController()..addGroups([_group('todo', 1)]);
      addTearDown(controller.dispose);

      controller.enableGroupDragging(true);
      expect(controller.groupDatas.single.draggable.value, isTrue);
    });
  });
}
