// 本文件守住的那句话：board 是唯一复用 `packages/board_panel` 的视图，它复刻的是
// 上游看板的三件事——每列一个"加载了多少"的窗口（`hasLoadedRecords`，列尾触底加载），
// 跨列拖拽写的是关系值本身，勾选类分组读成已勾选/未勾选两列。
//
// 三条坑都记录在案：① 拖拽要先让竞技场 settle 再越过 slop（workflow.md 那条）；
// ② board 的自动滚动 ticker 永不空闲，用固定帧而不是 pumpAndSettle；③ store 写盘在
// FakeAsync 里永不完成，轮询 finder 等的是同步通知触发的重建。

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/model/plan_object_type.dart';
import 'package:planstar/model/plan_space.dart';
import 'package:planstar/model/plan_struct.dart';
import 'package:planstar/state/plan_object_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/dataview/plan_cell_value.dart';
import 'package:planstar/ui/plan/dataview/plan_data_view_screen.dart';

const _collectionId = PlanMockKeys.taskSet;

PlanSpaceSeed _seedWithFiftyFiveTodos() {
  final base = planMockSeed();
  return PlanSpaceSeed(
    objects: [
      for (var i = 0; i < 55; i++)
        PlanObject(
          id: 'r-load-$i',
          struct: {
            PlanRelationKeys.name: 'Load item $i',
            PlanRelationKeys.type: PlanObjectTypeIds.task,
            PlanMockKeys.status: 'todo',
          },
        ),
      ...base.objects,
    ],
    collections: base.collections,
    types: base.types,
    relations: base.relations,
    templates: base.templates,
    widgets: base.widgets,
    bin: base.bin,
  );
}

void main() {
  late Directory root;
  AppDatabase? db;
  late PlanObjectStore store;

  setUp(() async {
    root = Directory.systemTemp.createTempSync('plan_board');
    db = AppDatabase.open(File('${root.path}/planstar.db'));
    store = await PlanObjectStore.open(
      db!,
      root: root,
      seed: _seedWithFiftyFiveTodos(),
    );
  });

  tearDown(() async {
    await db?.close();
    store.dispose();
    root.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        home: Scaffold(
          body: PlanDataViewScreen(store: store, collectionId: _collectionId),
        ),
      ),
    );
    // The board's auto-scroll ticker never idles: fixed frames only.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> frames(WidgetTester tester, [int count = 12]) async {
    for (var i = 0; i < count; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
  }

  testWidgets('a column shows one page and grows when scrolled to its end', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Load item 0'), findsOne);
    expect(find.text('Load item 49'), findsOne);
    expect(find.text('Load item 50'), findsNothing);

    // A pointer drag on a card belongs to the card's own drag recognizer, so
    // the column reaches its end the way a wheel does: drive the position to
    // its extent — the same scroll listener the package attaches for load-more.
    final context = tester.element(find.text('Load item 0').first);
    final position = Scrollable.of(context).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await frames(tester, 16);

    expect(find.text('Load item 50'), findsOne);
    expect(find.text('Load item 54'), findsOne);
    expect(
      store.stageFor(_collectionId, viewerId: 'v-board').ids,
      hasLength(60),
    );
  });

  testWidgets('a cross-column drag writes the relation itself', (tester) async {
    await pump(tester);
    expect(store.byId('r-task-1')!.text('status'), 'doing');

    final source = tester.getCenter(find.text('Ship the viewer bar'));
    final target = tester.getCenter(find.text('Todo').first);
    final gesture = await tester.startGesture(source);
    // The drag must let the arena settle first, then exceed the slop — a
    // single 26px jump never starts the board's drag at all.
    await tester.pump(const Duration(milliseconds: 700));
    const steps = 12;
    final delta =
        Offset(target.dx - source.dx, target.dy - source.dy) / steps.toDouble();
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(delta);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await frames(tester, 16);

    expect(store.byId('r-task-1')!.text('status'), 'todo');
  });

  testWidgets('a checkbox group reads as the two checked-state columns', (
    tester,
  ) async {
    await pump(tester);
    final viewer = store
        .collectionById(_collectionId)!
        .dataView
        .viewerById('v-board')!;
    unawaited(
      store.setViewerLayoutFull(
        _collectionId,
        'v-board',
        viewer.copyWith(groupRelationKey: PlanRelationKeys.done),
      ),
    );
    await frames(tester, 12);

    expect(find.text('Checked'), findsOne);
    expect(find.text('Unchecked'), findsOne);
    // The unchecked column holds the fifty-five seeded records plus the four
    // unfinished mock ones, so the named card past the page window answers
    // from the store, not from the culled tree.
    expect(find.text('Load item 0'), findsOne);
    expect(store.byId('r-task-5')!.relation('done'), isTrue);
    // The checked column comes after the unchecked one.
    final groups = store.stageFor(_collectionId, viewerId: 'v-board').groups;
    expect(groups.keys.toList(), ['false', 'true']);
  });

  testWidgets('colour columns paint the option colour onto the header band', (
    tester,
  ) async {
    await pump(tester);
    final doing = store.relationByKey(PlanMockKeys.status)!.option('doing')!;
    final expected = planLadderColor(
      tester.element(find.text('Doing').first).dsw,
      doing.colorIndex,
    );
    final band = find
        .ancestor(
          of: find.text('Doing').first,
          matching: find.byType(ColoredBox),
        )
        .first;
    expect(tester.widget<ColoredBox>(band).color, expected);
  });
}
