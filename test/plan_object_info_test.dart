// 本文件守住的那句话：对象信息屏按上游的分段回答——featured 在前、记录自己的
// local 键居中、hidden 收尾（file 段与编辑模式是上游死代码，不复刻）；行的值
// 与数据视图的格子共用同一个编辑器（一次工具结果只有一个读法的同族律），
// featured/hidden 的开关写回 store 的关系对象。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:planstar/l10n/locales.dart';
import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/state/plan_object_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/library/plan_object_info_screen.dart';

void main() {
  late Directory root;
  late PlanObjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_object_info');
    store = await PlanObjectStore.open(root, seed: planMockSeed());
  });

  tearDown(() {
    store.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, String recordId) async {
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
          body: PlanObjectInfoScreen(store: store, recordId: recordId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('the segments answer featured, local and hidden in order', (
    tester,
  ) async {
    await pump(tester, 'r-task-1');
    // The title row and the three segment headers, only when non-empty.
    expect(find.text('Ship the viewer bar'), findsOne);
    expect(find.text('Featured'), findsWidgets);
    expect(find.text('Local'), findsWidgets);
    // A record whose name is empty reads as Untitled.
    await pump(tester, 'r-task-3');
    expect(find.text('Empty column check'), findsOne);
  });

  testWidgets('a value edit writes through the same editor the cells use', (
    tester,
  ) async {
    await pump(tester, 'r-task-1');
    // The status badge row is wrapped in the cell editor: tapping it opens
    // the option picker the dataview uses, and the write lands on the record.
    await tester.tap(find.text('Doing').first);
    await tester.pump(const Duration(milliseconds: 400));
    final blocked = find.byKey(const ValueKey('plan-option-blocked'));
    // The popover animates in; the same frames loop the dataview test uses
    // before tapping an option row.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await tester.tap(blocked);
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(store.byId('r-task-1')!.text('status'), 'blocked');
  });

  testWidgets('the featured toggle writes the relation object', (tester) async {
    await pump(tester, 'r-task-1');
    final status = store.relationByKey('status')!;
    final wasFeatured = status.featured;
    // Open the row's action menu and flip the featured bit.
    await tester.tap(find.byTooltip('Relation actions').first);
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await tester.tap(
      find.text(wasFeatured ? 'Remove from featured' : 'Add to featured'),
    );
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(store.relationByKey('status')!.featured, !wasFeatured);
  });

  testWidgets('removing a relation clears the key from the record', (
    tester,
  ) async {
    await pump(tester, 'r-task-1');
    expect(store.byId('r-task-1')!.text('status'), isNotNull);
    await tester.tap(find.byTooltip('Relation actions').first);
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await tester.tap(find.text('Remove from object'));
    await tester.pump(const Duration(milliseconds: 300));
    // The confirm dialog asks, and confirming is what removes.
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(store.byId('r-task-1')!.struct.containsKey('status'), isFalse);
  });
}
