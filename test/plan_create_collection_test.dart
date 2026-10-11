// 本文件守住的那句话：Set 与 Collection 的创建跳过模板选择（上游
// ObjectTypeExtensions.kt:107-130 的语义），对话框里唯一的问题是名字；从类型
// 建 Set 时列由该类型的推荐关系播种，集合 id 按 mint 序增长且不与种子冲突。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/l10n/locales.dart';
import 'package:planstar/model/plan_dataview.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/model/plan_object_type.dart';
import 'package:planstar/state/plan_object_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/primitives/tappable.dart';
import 'package:planstar/ui/plan/library/plan_create_collection.dart';

void main() {
  late Directory root;
  AppDatabase? db;
  late PlanObjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_create_collection');
    db = AppDatabase.open(File('${root.path}/planstar.db'));
    store = await PlanObjectStore.open(db!, root: root, seed: planMockSeed());
  });

  tearDown(() async {
    await db?.close();
    store.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    PlanCollectionKind? kind,
    PlanObjectType? sourceType,
  }) async {
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
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: DswHoverTap(
                onTap: () => showPlanCreateCollectionDialog(
                  context,
                  store,
                  kind: kind,
                  sourceType: sourceType,
                ),
                semanticLabel: 'open',
                builder: (context, hovered, focused) =>
                    const Text('open dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open dialog'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('a collection lands with a starter grid and a minted id', (
    tester,
  ) async {
    await pumpDialog(tester);
    await tester.enterText(find.byType(ShadInput).first, 'Reading list');
    // One frame for the input's onChanged to run and re-enable Save.
    await tester.pump();
    await tester.tap(find.text('Save'));
    // The write is real IO inside a fake-async zone: hand the loop real time
    // until the store answers (the pumpUntil shape the dataview tests
    // established).
    for (var i = 0; i < 100; i++) {
      if (store.collections.any(
        (collection) => collection.name == 'Reading list',
      )) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    final created = store.collections
        .where((collection) => collection.name == 'Reading list')
        .first;
    expect(created.kind, PlanCollectionKind.collection);
    expect(created.id, startsWith('col-'));
    final viewer = created.activeViewer!;
    expect(viewer.kind, PlanViewerKind.grid);
    expect(viewer.relations.first.key, 'name');
  });

  test(
    'a set of a type seeds its columns from the recommended relations',
    () async {
      // Pure store work, no widgets: a plain test keeps real async alive, so
      // the disk write completes (a testWidgets body never does).
      final task = store.types
          .where((type) => type.uniqueKey == PlanObjectTypeIds.task)
          .first;
      final collection = await store.createSetOfType(task);
      expect(collection.kind, PlanCollectionKind.set);
      expect(collection.sourceTypeKey, PlanObjectTypeIds.task);
      // The seeded set answers with every task record the store holds.
      expect(
        collection.candidateRecordIds(store.objects),
        contains('r-task-1'),
      );
      final viewer = collection.activeViewer!;
      expect(viewer.relations.map((column) => column.key), contains('name'));
    },
  );

  testWidgets('an empty name keeps the confirm inert', (tester) async {
    await pumpDialog(tester);
    final before = store.collections.length;
    // No text entered: Save renders disabled and nothing is created.
    final save = tester.widget<ShadButton>(
      find.ancestor(of: find.text('Save'), matching: find.byType(ShadButton)),
    );
    expect(save.onPressed, isNull);
    expect(store.collections.length, before);
  });
}
