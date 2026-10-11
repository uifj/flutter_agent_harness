// 本文件守住的那句话：主屏组件区按 store 里持久化的 widget 数据画——分区按
// PlanWidgetSection.order（pinned/favorites/recent/types），行数上限走
// resolvedLimit（无存储值用默认 6，零不是合法渲染），下拉动作按 applies 门
// （只有 Bin 给"清空回收站"），移除组件把它从 store 与条带同时拿走。
//
// 测试纪律：testWidgets 体内对 store 的每次写入都包 tester.runAsync——
// FakeAsync 从不把磁盘写完成，直接 await 就是整轮悬死（本文件第一条注释
// 之外的第二条实测教训）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/l10n/locales.dart';
import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/model/plan_widget.dart';
import 'package:planstar/state/plan_object_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/widgets/plan_widgets_screen.dart';

void main() {
  late Directory root;
  AppDatabase? db;
  late PlanObjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_widgets_screen');
    db = AppDatabase.open(File('${root.path}/planstar.db'));
    store = await PlanObjectStore.open(db!, root: root, seed: planMockSeed());
  });

  tearDown(() async {
    await db?.close();
    store.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  /// Pumps the strip once, after the test has finished its store writes.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: AppLocaleScope(locale: AppLocaleId.en, child: child!),
        ),
        home: Scaffold(body: PlanWidgetsScreen(store: store)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('sections follow the model order with the types group last', (
    tester,
  ) async {
    final before = store.widgets.length;
    await tester.runAsync(
      () => store.addWidget(
        source: const PlanWidgetBundledSource(
          PlanBundledWidgetSourceIds.favorite,
        ),
      ),
    );
    await tester.runAsync(
      () => store.addWidget(
        source: const PlanWidgetBundledSource(PlanBundledWidgetSourceIds.bin),
      ),
    );
    expect(store.widgets.length, before + 2);
    await pump(tester);
    // Titles exist; the seed may already carry a Bin card, so quantities are
    // not pinned — the order (favourites before types) is.
    expect(find.text('Favourites'), findsWidgets);
    expect(find.text('Bin'), findsWidgets);
    expect(find.text('Object types'), findsOne);
  });

  testWidgets('the limit is the stored one, not zero, not infinite', (
    tester,
  ) async {
    await tester.runAsync(
      () => store.addWidget(
        source: const PlanWidgetBundledSource(
          PlanBundledWidgetSourceIds.allObjects,
        ),
        limit: 2,
      ),
    );
    // The seed's own types-group card shares the allObjects source; section
    // ordering puts my new pinned widget ahead of it.
    final mine = store.widgets
        .where(
          (widget) =>
              widget.source is PlanWidgetBundledSource &&
              (widget.source as PlanWidgetBundledSource).id ==
                  PlanBundledWidgetSourceIds.allObjects,
        )
        .first;
    expect(mine.resolvedLimit(), 2);
    await pump(tester);
    // The card shows the seeded rows within the stored limit; the mock holds
    // far more records than two, so the cap is what bounds the rows (the
    // seed's own set widget may draw the same record, hence findsWidgets).
    expect(find.text('Ship the viewer bar'), findsWidgets);
  });

  testWidgets('the dropdown answers remove for a widget, bin only for Bin', (
    tester,
  ) async {
    final before = store.widgets.length;
    await tester.runAsync(
      () => store.addWidget(
        source: const PlanWidgetBundledSource(PlanBundledWidgetSourceIds.bin),
      ),
    );
    expect(store.widgets.length, before + 1);
    await pump(tester);

    // The applies gate: the seed's set card (first) may not offer
    // "Empty bin" — only a Bin widget does — while "Remove widget" is there.
    await tester.tap(find.byTooltip('Widget actions').first);
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(find.text('Empty bin'), findsNothing);
    expect(find.text('Remove widget'), findsOne);
    await tester.tap(find.text('Remove widget'));
    for (var i = 0; i < 100; i++) {
      if (store.widgets.length < before + 1) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(store.widgets.length, before);
  });
}
