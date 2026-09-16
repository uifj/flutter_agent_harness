import 'package:board_panel/board_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadBreakpoints;

class _TextItem extends BoardPanelGroupItem {
  _TextItem(this.title);

  final String title;

  @override
  String get id => title;
}

Widget _buildBoard({
  required BoardPanelController controller,
  BoardPanelConfig config = const BoardPanelConfig(),
}) {
  return MaterialApp(
    home: Scaffold(
      body: BoardPanel(
        controller: controller,
        cardBuilder: (context, group, groupItem) => BoardPanelGroupCard(
          key: ValueKey(groupItem.id),
          child: Text(groupItem.id, key: Key('card_${groupItem.id}')),
        ),
        headerBuilder: (context, group) => BoardPanelGroupHeader(
          height: 40,
          title: Text(
            group.headerData.groupName,
            key: Key('header_${group.id}'),
          ),
        ),
        config: config,
      ),
    ),
  );
}

BoardPanelController _seedController() {
  return BoardPanelController()..addGroups([
    BoardPanelGroupData(
      id: 'todo',
      name: 'To Do',
      items: <BoardPanelGroupItem>[_TextItem('a'), _TextItem('b')],
    ),
    BoardPanelGroupData(
      id: 'doing',
      name: 'Doing',
      items: <BoardPanelGroupItem>[_TextItem('c')],
    ),
  ]);
}

void main() {
  group('ResponsiveBoardDirection', () {
    test('resolves vertical below md and horizontal from md upwards', () {
      const direction = ResponsiveBoardDirection.mobileVertical();
      final breakpoints = ShadBreakpoints();

      expect(
        direction.resolve(breakpoints.fromWidth(390), breakpoints),
        Axis.vertical,
      );
      expect(
        direction.resolve(breakpoints.fromWidth(1024), breakpoints),
        Axis.horizontal,
      );
    });
  });

  group('BoardPanel responsive direction', () {
    testWidgets('phone-sized viewport stacks groups vertically', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _seedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildBoard(
          controller: controller,
          config: const BoardPanelConfig(
            responsiveDirection: ResponsiveBoardDirection.mobileVertical(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(find.byKey(const Key('header_todo')));
      final second = tester.getTopLeft(find.byKey(const Key('header_doing')));
      // Stacked: the second group sits below (not beside) the first one.
      expect(second.dy, greaterThan(first.dy));
      expect(second.dx, first.dx);
      expect(controller.layoutDirection.value, Axis.vertical);
    });

    testWidgets('desktop-sized viewport keeps horizontal columns', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _seedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        _buildBoard(
          controller: controller,
          config: const BoardPanelConfig(
            responsiveDirection: ResponsiveBoardDirection.mobileVertical(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(find.byKey(const Key('header_todo')));
      final second = tester.getTopLeft(find.byKey(const Key('header_doing')));
      // Side by side: the second group sits to the right of the first one.
      expect(second.dx, greaterThan(first.dx));
      expect(second.dy, first.dy);
      expect(controller.layoutDirection.value, Axis.horizontal);
    });

    testWidgets('no responsiveDirection keeps legacy horizontal layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final controller = _seedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_buildBoard(controller: controller));
      await tester.pumpAndSettle();

      final first = tester.getTopLeft(find.byKey(const Key('header_todo')));
      final second = tester.getTopLeft(find.byKey(const Key('header_doing')));
      expect(second.dx, greaterThan(first.dx));
      expect(controller.layoutDirection.value, Axis.horizontal);
    });
  });
}
