// 本文件守住的那句话：All Content 是纯查询面——tab 按类型的布局清单过滤，
// Unlinked 模式只留没有链接的记录，时间分组按"今天/昨天/7 天/14 天/月/年"的
// 桶序回答（now 可注入，断言不随机器日期漂移），排序与方向整体可逆，状态经
// onStateChanged 回流给持有者（RestoreAllContentState 的等价）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:planstar/l10n/locales.dart';
import 'package:planstar/model/plan_all_content.dart';
import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/model/plan_object_type.dart';
import 'package:planstar/model/plan_struct.dart';
import 'package:planstar/state/plan_object_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/library/plan_all_content_screen.dart';

void main() {
  late Directory root;
  late PlanObjectStore store;
  PlanAllContentState? lastState;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_all_content');
    store = await PlanObjectStore.open(root, seed: planMockSeed());
    lastState = null;
  });

  tearDown(() {
    store.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {PlanAllContentState? initial}) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: AppLocaleScope(locale: AppLocaleId.en, child: child!),
        ),
        home: Scaffold(
          body: PlanAllContentScreen(
            store: store,
            initial: initial ?? const PlanAllContentState(),
            now: DateTime(2026, 10, 20, 12),
            onStateChanged: (state) => lastState = state,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('the pure layer', () {
    test('tabs map onto the type keys the layouts ask for', () {
      expect(
        PlanAllContentTab.pages.typeKeys,
        contains(PlanObjectTypeIds.page),
      );
      expect(PlanAllContentTab.bookmarks.typeKeys, [
        PlanObjectTypeIds.bookmark,
      ]);
      expect(PlanAllContentTab.files.typeKeys, [PlanObjectTypeIds.file]);
    });

    test('grouping answers the bucket order with empty buckets dropped', () {
      PlanObject at(String id, String iso) =>
          PlanObject(id: id, struct: {'editedAt': iso});
      final groups = groupPlanAllContent([
        at('today', '2026-10-20T09:00'),
        at('yesterday', '2026-10-19T09:00'),
        at('in7', '2026-10-15T09:00'),
        at('in14', '2026-10-08T09:00'),
        at('month', '2026-10-03T09:00'),
        at('year', '2026-09-15T09:00'),
        at('older', '2025-01-01T09:00'),
      ], DateTime(2026, 10, 20, 12));
      expect(groups.keys.toList(), [
        PlanAllContentGroup.today,
        PlanAllContentGroup.yesterday,
        PlanAllContentGroup.previous7Days,
        PlanAllContentGroup.previous14Days,
        PlanAllContentGroup.month,
        PlanAllContentGroup.monthAndYear,
        PlanAllContentGroup.older,
      ]);
      expect(groups[PlanAllContentGroup.month]!.single.id, 'month');
      expect(groups[PlanAllContentGroup.older]!.single.id, 'older');
    });

    test('a record edited in the future reads as today, not as a crash', () {
      final groups = groupPlanAllContent([
        PlanObject(id: 'ahead', struct: {'editedAt': '2027-01-01T09:00'}),
      ], DateTime(2026, 10, 20, 12));
      expect(groups.keys.single, PlanAllContentGroup.today);
    });

    test('sort inverts wholesale and keeps the id tie-break stable', () {
      final a = PlanObject(id: 'a', struct: {'editedAt': '2026-10-01'});
      final b = PlanObject(id: 'b', struct: {'editedAt': '2026-09-01'});
      expect(
        sortPlanAllContent(
          [a, b],
          PlanAllContentSort.modified,
          ascending: false,
        ).map((record) => record.id).toList(),
        ['a', 'b'],
      );
      expect(
        sortPlanAllContent(
          [a, b],
          PlanAllContentSort.modified,
          ascending: true,
        ).map((record) => record.id).toList(),
        ['b', 'a'],
      );
    });
  });

  group('the screen', () {
    testWidgets('tabs narrow the records to their layouts', (tester) async {
      await pump(tester);
      // The mock's tasks land in PAGES; FILES has none in the seed.
      expect(find.text('Ship the viewer bar'), findsOne);
      await tester.tap(find.text('Files'));
      await tester.pump();
      expect(find.text('Nothing here yet'), findsOne);
      expect(find.text('Ship the viewer bar'), findsNothing);
    });

    testWidgets('the unlinked mode toggles and flows back', (tester) async {
      await pump(tester);
      // The chip shows the current mode and toggles on tap.
      await tester.tap(find.text('All content').last);
      await tester.pump();
      expect(lastState?.unlinked, isTrue);
      expect(find.text('Unlinked'), findsOne);
    });

    testWidgets('sort state flows back through onStateChanged', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Name'));
      await tester.pump();
      expect(lastState?.sort, PlanAllContentSort.name);
    });
  });
}
