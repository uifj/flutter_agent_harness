// 本文件守住的那句话：企划里的一个集合，画的是 store 的当前答案——切视图会换面孔，
// 不支持的视图会**说出来**，改一格值会立刻回到 store 并刷出这一行。
//
// ADR-0037 P3 的守卫。四条历史教训都挂在这里：
//  1) 渲染 store 的面必须订阅 store（ADR-0007 那次"表格只读不听"的缺陷）；
//  2) `testWidgets` 里**不等** store 的写盘（FakeAsync 不交回真实事件循环，`await`
//     会把整轮挂死且没有栈）——沿 `plan_extensions_view_test` 的 `unawaited` + 轮询 finder；
//  3) 放大文本两档（1.8x / 2.2x），尺子挂在 `MaterialApp.builder` 那道缝上；
//  4) 图标即控件必须自报姓名（`unlabelledIconControls`）。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:agent_harness/model/plan_dataview.dart';
import 'package:agent_harness/model/plan_mock_content.dart';
import 'package:agent_harness/model/plan_struct.dart';
import 'package:agent_harness/state/plan_object_store.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/plan/dataview/plan_data_view_screen.dart';

import 'amplified_text_probe.dart';

const _collectionId = 'set-tasks';
const _calendarCopy =
    'Calendar view is not available in this workspace yet. '
    'Change the view type, or create a new view to reach your data.';
const _graphCopy =
    'Graph view is not available in this workspace yet. '
    'Change the view type, or create a new view to reach your data.';

void main() {
  late Directory root;
  late PlanObjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_dataview');
    store = await PlanObjectStore.open(root, seed: planMockSeed());
  });

  tearDown(() async {
    store.dispose();
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    double step = 1.0,
    Size size = const Size(1400, 1000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: AmplifiedText(step: step, child: child!),
        ),
        home: Scaffold(
          body: PlanDataViewScreen(store: store, collectionId: _collectionId),
        ),
      ),
    );
    // The board's auto-scroll ticker never idles, so `pumpAndSettle` has no end
    // to reach: fixed frames, the way the board panel's own test pumps it.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  /// Pump until [finder] exists: a store write's repaint lands on some frame
  /// after the tap, and `await`ing the write itself would hang the run.
  Future<void> settled(WidgetTester tester, Finder finder) async {
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('the widget never appeared: $finder');
  }

  Future<void> gone(WidgetTester tester, Finder finder) async {
    for (var frame = 0; frame < 24; frame++) {
      await tester.pump(const Duration(milliseconds: 32));
      if (finder.evaluate().isEmpty) return;
    }
    fail('the widget never went away: $finder');
  }

  testWidgets('the board is the default view and every status is a column', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Delivery board'), findsOne);
    expect(find.text('Ship the viewer bar'), findsOne);
    expect(find.text('Todo'), findsWidgets);
    expect(find.text('No status'), findsOne);
    // A record without the group value is reachable, not swallowed.
    expect(find.text('Empty column check'), findsOne);
  });

  testWidgets('archiving a record takes it out of every view', (tester) async {
    await pump(tester);
    final row = find.text('Relation value editors for all eleven formats');
    expect(row, findsOne);
    unawaited(store.archiveRecords(['r-task-2']));
    await gone(tester, row);
    expect(store.binIds, contains('r-task-2'));
    expect(
      store.stageFor(_collectionId, viewerId: 'v-board').ids,
      isNot(contains('r-task-2')),
    );
  });

  testWidgets('the panel subscribes: a store write repaints it from itself', (
    tester,
  ) async {
    await pump(tester);
    expect(store.subscriptionsFor(_collectionId), 1);
    unawaited(store.amendRecord('r-task-3', {'status': 'doing'}));
    await settled(tester, find.text('Empty column check'));
    expect(store.byId('r-task-3')!.text('status'), 'doing');
  });

  testWidgets('switching to the gallery view changes the face of the data', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Cards'));
    await settled(tester, find.text('Ship the viewer bar'));
    await frames(tester, 4);
    expect(find.text('Effort'), findsNothing);
  });

  testWidgets('calendar answers "not available here", in words', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Calendar'));
    await settled(tester, find.text(_calendarCopy));
    expect(find.text('Ship the viewer bar'), findsNothing);
  });

  testWidgets('the sort sheet shows what is sorted on, and a new order lands', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('All tasks'));
    await settled(tester, find.text('Effort'));
    await tester.tap(find.byTooltip('Sort'));
    await settled(tester, find.text('Due'));
    unawaited(
      store.setViewerSorts(_collectionId, 'v-table', const [
        PlanSort(
          relationKey: 'dueDate',
          type: PlanSortType.desc,
          // Placement is absolute (pinned in plan_filter_engine_test):
          // `start` holds the dateless records at the top while desc only
          // flips the dated values among themselves.
          emptyPlacement: PlanSortEmptyPlacement.start,
        ),
      ]),
    );
    await settled(tester, find.text('Empty column check'));
    final ids = store.stageFor(_collectionId, viewerId: 'v-table').ids;
    expect(
      ids.first,
      'r-task-3',
      reason: 'the two dateless records come first',
    );
  });

  testWidgets('a status cell opens the picker and writes the option through', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('All tasks'));
    await settled(tester, find.text('Effort'));
    await tester.tap(find.text('Doing').first);
    final blocked = find.byKey(const ValueKey('plan-option-blocked'));
    await settled(tester, blocked);
    // The popover animates in; a tap on the first frame it exists lands on a
    // scale/fade at t=0 and warns it missed — the same trap the sidebar's
    // two-phase collapse recorded. Let the entrance finish before tapping.
    await frames(tester, 10);
    await tester.tap(blocked);
    await settled(tester, find.text('Blocked'));
    expect(store.byId('r-task-1')!.text('status'), 'blocked');
  });

  testWidgets('an in-set filter narrows the grid to the values it names', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('All tasks'));
    await settled(tester, find.text('Effort'));
    final before = store
        .stageFor(_collectionId, viewerId: 'v-table')
        .ids
        .length;
    unawaited(
      store.setViewerFilters(_collectionId, 'v-table', const [
        PlanFilter(
          relationKey: 'status',
          condition: PlanFilterCondition.inSet,
          value: ['todo', 'doing'],
        ),
      ]),
    );
    await frames(tester, 8);
    final after = store.stageFor(_collectionId, viewerId: 'v-table').ids;
    expect(after.length, lessThan(before));
    expect(after, isNot(contains('r-task-5')));
    // The narrowing is visible: the shipped row leaves the grid, not just the
    // stage answer.
    await gone(tester, find.text('Kanban gate shipped'));
  });

  testWidgets('a view renamed in the store shows in the tab strip', (
    tester,
  ) async {
    await pump(tester);
    unawaited(store.renameViewer(_collectionId, 'v-gallery', 'Cards big'));
    await settled(tester, find.text('Cards big'));
  });

  testWidgets(
    'the plus menu offers every kind and the new one becomes active',
    (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('New view'));
      // The seeded Graph tab shares the label, so the menu row is the last one.
      await settled(tester, find.text('Graph').last);
      await tester.tap(find.text('Graph').last);
      await settled(tester, find.text(_graphCopy));
      expect(
        store.collectionById(_collectionId)!.activeViewer!.kind,
        PlanViewerKind.graph,
      );
    },
  );

  testWidgets('a read-only collection loses the plus and the sheets', (
    tester,
  ) async {
    await pump(tester);
    unawaited(
      store.setCollectionRestrictions(_collectionId, const {
        PlanDataViewRestriction.views,
        PlanDataViewRestriction.createObject,
      }),
    );
    await settled(tester, find.text('Delivery board'));
    await frames(tester, 6);
    expect(find.byTooltip('New view'), findsNothing);
    expect(find.byTooltip('Sort'), findsNothing);
    // Records still draw; only the affordances are gated away.
    expect(find.text('Ship the viewer bar'), findsOne);
  });

  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('every viewer keeps its labels at $label', (tester) async {
        for (final view in [
          'Board',
          'All tasks',
          'Open only',
          'Cards',
          'Calendar',
        ]) {
          await pump(tester, step: step);
          await tester.tap(find.text(view));
          await settled(tester, find.text(view));
          await frames(tester, 4);
          expect(textDefects(tester), isEmpty, reason: view);
        }
      });

      testWidgets('a narrow panel keeps its header and strip at $label', (
        tester,
      ) async {
        await pump(tester, step: step, size: const Size(520, 900));
        await tester.tap(find.text('All tasks'));
        await settled(tester, find.text('Effort'));
        expect(textDefects(tester), isEmpty);
        expect(find.text('Delivery board'), findsOne);
      });
    }
  });

  testWidgets('every icon-only control in the data view names itself', (
    tester,
  ) async {
    await pump(tester);
    expect(unlabelledIconControls(tester), isEmpty);
  });
}
