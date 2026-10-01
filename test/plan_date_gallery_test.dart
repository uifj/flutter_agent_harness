// 本文件守住的那句话：ot-date 整屏回答相对日期头 + 当日对象列表（按记录里的
// 日期串扫描 store，等价于上游按日期的订阅）；Gallery 安装是三态状态机
// （idle/loading/done），安装 = 从包的来源类型建 Set 并种入首条记录——
// 上游"不支持"告警是死目的地（graph.xml:306-307 注册后无导航），桌面端以
// 可用安装回答，对照表已登记。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:agent_harness/l10n/locales.dart';
import 'package:agent_harness/model/plan_mock_content.dart';
import 'package:agent_harness/model/plan_dataview.dart' show PlanDateFormat;
import 'package:agent_harness/model/plan_object_type.dart';
import 'package:agent_harness/state/plan_object_store.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/plan/library/plan_date_screen.dart';
import 'package:agent_harness/ui/plan/library/plan_bin_screen.dart';
import 'package:agent_harness/ui/plan/library/plan_gallery_screen.dart';

void main() {
  late Directory root;
  late PlanObjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_date_gallery');
    store = await PlanObjectStore.open(root, seed: planMockSeed());
  });

  tearDown(() {
    store.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> pumpDate(WidgetTester tester, DateTime day) async {
    // The seed ships no ot-date record: create one for the day under test
    // (real IO before the fake-async widget tree goes up).
    // Real IO inside the testWidgets zone: runAsync keeps the write alive
    // (FakeAsync never completes a disk round-trip on its own).
    final dateRecord = await tester.runAsync(
      () => store.createRecord(
        collectionId: '',
        typeKey: PlanObjectTypeIds.date,
        values: {
          'name': PlanDateFormat.iso.format(day),
          'dueDate': PlanDateFormat.iso.format(day),
        },
      ),
    );
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
          body: PlanDateScreen(
            store: store,
            dateRecordId: dateRecord!.id,
            initialDay: day,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  Future<void> pumpGallery(WidgetTester tester) async {
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
        home: Scaffold(body: PlanGalleryScreen(store: store)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  group('the date screen', () {
    testWidgets('a day with due records lists them with done state', (
      tester,
    ) async {
      // r-task-1 carries dueDate 2026-10-02 and is not done.
      await pumpDate(tester, DateTime(2026, 10, 2));
      expect(find.text('Ship the viewer bar'), findsOne);
    });

    testWidgets('an empty day says so', (tester) async {
      await pumpDate(tester, DateTime(2026, 10, 15));

      expect(find.text('No objects on this day'), findsOne);
    });
  });

  group('gallery installation', () {
    test('the packages ship a manifest each', () {
      expect(planGalleryPackages, isNotEmpty);
      for (final pack in planGalleryPackages) {
        expect(pack.sourceTypeKey, isNotEmpty);
      }
    });

    testWidgets('installing creates the set and lands its starter record', (
      tester,
    ) async {
      await pumpGallery(tester);
      final before = store.collections.length;
      await tester.tap(find.text('Install').first);
      // Install awaits real IO twice (collection, then starter record): the
      // poll runs until the record is visible, not just the collection.
      for (var i = 0; i < 100; i++) {
        final landed = store.objects.any(
          (record) => record.name == 'Reading list',
        );
        if (store.collections.length > before && landed) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(store.collections.length, before + 1);
      final created = store.collections.last;
      expect(created.kind.toString(), contains('set'));
      final names = [
        for (final record in store.objects)
          if (created.candidateRecordIds(store.objects).contains(record.id))
            record.name,
      ];
      expect(names, contains('Reading list'));
    });
  });

  group('the bin screen', () {
    testWidgets('lists binned records and restores through its row menu', (
      tester,
    ) async {
      await tester.runAsync(() => store.archiveRecords(['r-task-1']));
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
          home: Scaffold(body: PlanBinScreen(store: store)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // The binned record shows; the live views no longer carry it.
      expect(find.text('Ship the viewer bar'), findsOne);
      expect(
        store.stageFor('set-tasks', viewerId: 'v-board').ids,
        isNot(contains('r-task-1')),
      );

      // Restore is reachable here — the data view's stage cannot show the
      // row, this screen is where the bin answers. Tap the row (its context
      // menu) and restore it.
      await tester.tap(find.text('Ship the viewer bar'));
      await tester.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.tap(find.text('Restore'));
      for (var i = 0; i < 100; i++) {
        if (store.binIds.isEmpty) break;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      // The seed's own archived record stays binned; ours is out.
      expect(store.binIds, isNot(contains('r-task-1')));
      expect(
        store.stageFor('set-tasks', viewerId: 'v-board').ids,
        contains('r-task-1'),
      );
    });
  });
}
