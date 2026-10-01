// 本文件守住的那句话：企划笔记的 Edit 面是块编辑器——它解码盘上的 Markdown，
// slash 是唯一插入入口，工具栏作用于聚焦块，undo 按快照回滚，保存走编解码器
// 的往返（不是把内存字符串原样倒回盘上）。
//
// 两档放大与图标命名两把尺子照挂；搜索的六事件在只读面回答（与上游先转
// Read 再搜索同一决定）。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:agent_harness/model/plan_block.dart';
import 'package:agent_harness/state/plan_block_document.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/plan/blocks/plan_block_editor.dart';
import 'package:agent_harness/ui/plan/plan_workspace.dart';

import 'amplified_text_probe.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('plan_blocks');
    File(
      '${root.path}/readme.md',
    ).writeAsStringSync('# readme\n\nhello world\n');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Future<void> pump(WidgetTester tester, {double step = 1.0}) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: AmplifiedText(step: step, child: child!),
        ),
        home: Scaffold(body: PlanWorkspace(workspaceRoot: root.path)),
      ),
    );
    // The vault index runs on a compute isolate: real time, then frames.
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text('readme.md').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.tap(find.text('readme.md'));
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.byType(PlanBlockEditor).evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pump();
  }

  PlanBlockDocument documentOf(WidgetTester tester) =>
      tester.widget<PlanBlockEditor>(find.byType(PlanBlockEditor)).document;

  testWidgets('the block editor decodes the note and saves through the codec', (
    tester,
  ) async {
    await pump(tester);
    // The note's two text blocks are two fields: heading and paragraph.
    expect(find.text('readme'), findsOne);
    expect(find.text('hello world'), findsOne);

    // ShadInput wraps an EditableText, not a TextField.
    await tester.enterText(find.byType(EditableText).first, 'readme edited');
    // One frame flushes the edit; the dirty flag rides a microtask out of the
    // bridge's build, so it lands on the frame after that.
    await tester.pump();
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOne);

    await tester.tap(find.text('Save'));
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text('Unsaved changes').evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    final saved = File('${root.path}/readme.md').readAsStringSync();
    expect(saved, contains('readme edited'));
    // The codec re-encodes the whole tree, so the untouched paragraph
    // survives the round trip.
    expect(saved, contains('hello world'));
  });

  testWidgets('the slash sheet inserts a block below the active one', (
    tester,
  ) async {
    await pump(tester);
    final before = documentOf(tester).blocks.length;

    await tester.tap(find.text('Add block'));
    // The sheet animates in; a tap on the first frame lands outside it.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Divider line'));
    await tester.pump();

    expect(documentOf(tester).blocks.length, before + 1);
  });

  testWidgets('undo rolls the insertion back', (tester) async {
    await pump(tester);
    final before = documentOf(tester).blocks.length;

    await tester.tap(find.text('Add block'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Divider line'));
    await tester.pump();
    expect(documentOf(tester).blocks.length, before + 1);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(documentOf(tester).blocks.length, before);
  });

  testWidgets('the slash sheet filters as you type and lands a real table', (
    tester,
  ) async {
    await pump(tester);
    final before = documentOf(tester).blocks.length;

    await tester.tap(find.text('Add block'));
    await tester.pump(const Duration(milliseconds: 400));
    // The filter field narrows the sections: 'div' leaves the two dividers.
    final filterField = find
        .descendant(
          of: find.byType(ShadDialog),
          matching: find.byType(EditableText),
        )
        .first;
    await tester.enterText(filterField, 'divider');
    await tester.pump();
    // Only labels containing the query survive - Three dots does not.
    expect(find.text('Divider line'), findsOne);
    expect(find.text('Three dots'), findsNothing);

    await tester.enterText(filterField, 'table');
    await tester.pump();
    await tester.tap(find.text('Simple table'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // A real table run (3 header cells), not the old unsupported chip.
    final doc = documentOf(tester);
    expect(doc.blocks.length, before + 3);
    final header = doc.blocks
        .where((block) => block.content is PlanTableBlock)
        .first;
    expect((header.content as PlanTableBlock).isHeader, isTrue);
    expect(header.children, hasLength(3));
  });

  testWidgets('a selection takes the toolbar marks, and they survive a save', (
    tester,
  ) async {
    await pump(tester);
    // Select the paragraph text, then apply bold and underline.
    final paragraph = find.byType(EditableText).at(1);
    await tester.enterText(paragraph, 'hello marks');
    await tester.pump();
    // Selecting through the EditableText's widget controller: the widget
    // carries the controller this state drives.
    tester.widget<EditableText>(paragraph).controller.selection =
        const TextSelection(baseOffset: 0, extentOffset: 5);
    await tester.pump();

    await tester.tap(find.byTooltip('Bold'));
    await tester.pump();
    await tester.tap(find.byTooltip('Underline'));
    await tester.pump();
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    final doc = documentOf(tester);
    final marked = doc.blocks
        .map((block) => block.content)
        .whereType<PlanText>()
        .where((content) => content.text == 'hello marks')
        .first;
    expect(
      marked.marks.map((mark) => mark.type),
      containsAll([PlanMarkType.bold, PlanMarkType.underline]),
    );

    // The marks survive the save — the envelope guarantees the round trip.
    await tester.tap(find.text('Save'));
    for (var i = 0; i < 100; i++) {
      if (find.text('Unsaved changes').evaluate().isEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    final saved = File('${root.path}/readme.md').readAsStringSync();
    final reopened = PlanBlockDocument.fromMarkdown(saved);
    final restored = reopened.blocks
        .map((block) => block.content)
        .whereType<PlanText>()
        .where((content) => content.text == 'hello marks')
        .first;
    expect(
      restored.marks.map((mark) => mark.type),
      containsAll([PlanMarkType.bold, PlanMarkType.underline]),
    );
  });

  testWidgets('search answers its six events in read mode', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Search in document'));
    await tester.pump();

    await tester.enterText(find.byType(ShadInput).first, 'hello');
    await tester.pump();
    expect(find.text('1 / 1'), findsOne);

    // Next on a single match stays on it; the cycle keeps the count honest.
    await tester.tap(find.byTooltip('Next match'));
    await tester.pump();
    expect(find.text('1 / 1'), findsOne);

    await tester.enterText(find.byType(ShadInput).first, 'zzz');
    await tester.pump();
    expect(find.text('0'), findsOne);

    await tester.tap(find.byTooltip('Stop searching'));
    await tester.pump();
    expect(find.byTooltip('Search in document'), findsOne);
  });
}
