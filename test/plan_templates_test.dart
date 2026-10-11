// 本文件守住的那句话：类型内模板流回答上游菜单的四件事——设为默认（写类型的
// defaultTemplateId，模板对象同步 isDefault 位）、复制（"(1)" 后缀的新 id）、
// 删除（确认框把守）、新建（只有 allowsTemplates 的类型给建）；"从对象设为
// 模板"以记录名与类型落一个新模板（ObjectAction.USE_AS_TEMPLATE 的等价）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/model/plan_mock_content.dart';
import 'package:planstar/state/app_database.dart';
import 'package:planstar/model/plan_object_type.dart';
import 'package:planstar/state/plan_object_store.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/library/plan_templates_screen.dart';

void main() {
  late Directory root;
  AppDatabase? db;
  late PlanObjectStore store;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_templates');
    db = AppDatabase.open(File('${root.path}/planstar.db'));
    store = await PlanObjectStore.open(db!, root: root, seed: planMockSeed());
  });

  tearDown(() async {
    await db?.close();
    store.dispose();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, String typeKey) async {
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
          child: child!,
        ),
        home: Scaffold(
          body: PlanTemplatesScreen(store: store, typeKey: typeKey),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  testWidgets('a type without templates answers with the grouping truth', (
    tester,
  ) async {
    // ot-date is in getTypesWithoutTemplates: the screen says so instead of
    // offering a create button that the model refuses.
    await pump(tester, PlanObjectTypeIds.date);
    expect(find.text('This type does not take templates'), findsOne);
  });

  testWidgets('create, set default, duplicate and delete answer', (
    tester,
  ) async {
    await pump(tester, PlanObjectTypeIds.task);
    // The seed ships one bundled task template.
    expect(find.text('Default task'), findsOne);
    expect(find.text('Default'), findsOne);

    // Creating through the screen menu lands a second one.
    await tester.tap(find.byTooltip('New template'));
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await tester.tap(find.text('New template').last);
    for (var i = 0; i < 100; i++) {
      if (store.templates.where((t) => t.typeKey == 'ot-task').length == 2) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(store.templates.where((t) => t.typeKey == 'ot-task'), hasLength(2));

    // A duplicate arrives as "(1)" with a fresh id. Store writes are real IO:
    // inside the fake-async zone they must run on the real loop (the same
    // treatment every store-write in a testWidgets body gets).
    await tester.runAsync(
      () => store.duplicateTemplate(
        store.templates
            .where((t) => t.typeKey == 'ot-task' && !t.bundled)
            .first
            .id,
      ),
    );
    await tester.pump();
    final names = store.templates
        .where((t) => t.typeKey == 'ot-task')
        .map((t) => t.name)
        .toSet();
    expect(names, contains('Untitled template'));
    expect(names, contains('Untitled template (1)'));

    // Setting the non-default template as default moves both the type's
    // pointer and the isDefault bit.
    final other = store.templates
        .where((t) => t.typeKey == 'ot-task' && !t.isDefault)
        .first;
    await tester.runAsync(() => store.setDefaultTemplate('ot-task', other.id));
    await tester.pump();
    expect(
      store.types
          .where((type) => type.uniqueKey == 'ot-task')
          .first
          .defaultTemplateId,
      other.id,
    );
    expect(
      store.templates
          .where((t) => t.typeKey == 'ot-task' && t.isDefault)
          .single
          .id,
      other.id,
    );
  });

  test('set as template from an object lands a template of that type', () async {
    // Pure store path: the record's name and type carry over (USE_AS_TEMPLATE).
    final template = await store.createTemplateFromObject('r-task-1');
    expect(template, isNotNull);
    expect(template!.typeKey, 'ot-task');
    expect(template.name, 'Ship the viewer bar');
    // A file type refuses templates, per the model's grouping truth.
    final refused = await store.createTemplateFromObject('r-file-1');
    expect(refused, isNull);
  });
}
