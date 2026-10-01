// 本文件守住的那句话：企划笔记的 Edit 面是块编辑器——它解码盘上的 Markdown，
// slash 是唯一插入入口，工具栏作用于聚焦块，undo 按快照回滚，保存走编解码器
// 的往返（不是把内存字符串原样倒回盘上）。
//
// 两档放大与图标命名两把尺子照挂；搜索的六事件在只读面回答（与上游先转
// Read 再搜索同一决定）。
//
// P9 批（ADR-0040）：toggle/numbered/quote/callout 有自己的长相与交互，
// 书签的 URL 有入口，table(RxC) 有尺寸，表头有列菜单，块菜单有内部剪贴板。

import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:agent_harness/model/plan_block.dart';
import 'package:agent_harness/state/plan_block_document.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/plan/blocks/plan_block_actions.dart';
import 'package:agent_harness/ui/plan/blocks/plan_block_editor.dart';
import 'package:agent_harness/ui/plan/blocks/plan_block_view.dart';
import 'package:agent_harness/ui/plan/dataview/plan_viewers.dart'
    show PlanCheckbox;
import 'package:agent_harness/ui/plan/plan_workspace.dart';
import 'package:agent_harness/ui/primitives/tappable.dart';

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

  // ---- P9 (ADR-0040): the styles draw as themselves -----------------------

  testWidgets('a toggle folds its children away and back', (tester) async {
    // A toggle with children only arrives through the envelope: markdown has
    // no nesting, so this is also the round-trip entry path.
    const toggle = PlanBlock(
      id: 't1',
      content: PlanText(text: 'open me', style: PlanTextStyle.toggle),
      children: [
        PlanBlock(
          id: 'c1',
          content: PlanText(text: 'inside child'),
        ),
      ],
    );
    File(
      '${root.path}/readme.md',
    ).writeAsStringSync('<!-- plan:${jsonEncode(toggle.toJson())} -->');
    await pump(tester);
    expect(find.text('inside child'), findsOne);

    await tester.tap(find.bySemanticsLabel('Toggle section'));
    await tester.pump();
    expect(find.text('inside child'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Toggle section'));
    await tester.pump();
    expect(find.text('inside child'), findsOne);
  });

  testWidgets('numbered runs count themselves, a break restarts them', (
    tester,
  ) async {
    File(
      '${root.path}/readme.md',
    ).writeAsStringSync('1. first\n2. second\n\nplain\n\n3. restarts at one\n');
    await pump(tester);
    // Two runs: first/second and the post-break block — both read "1.".
    expect(find.text('1.'), findsNWidgets(2));
    expect(find.text('2.'), findsOne);
    expect(find.text('3.'), findsNothing);
  });

  bool isQuoteRule(Widget widget) {
    if (widget is! DecoratedBox) return false;
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) return false;
    final border = decoration.border;
    return border is Border && border.left.width == 2;
  }

  testWidgets('quote draws its brand rule in the edit face', (tester) async {
    File('${root.path}/readme.md').writeAsStringSync('> quoted line\n');
    await pump(tester);
    expect(find.byWidgetPredicate(isQuoteRule), findsOneWidget);
  });

  testWidgets('the read face keeps the row identities search would lose', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final doc = PlanBlockDocument.fromMarkdown(
      '> quoted\n\n- [x] done\n- open\n\n1. one\n',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanBlockView(document: doc, readOnly: true),
          ),
        ),
      ),
    );
    // The quote rule survives into the read face.
    expect(find.byWidgetPredicate(isQuoteRule), findsOneWidget);
    // The checkbox keeps its state, the bullet its dot, the counter its number.
    final checkbox = tester.widget<PlanCheckbox>(find.byType(PlanCheckbox));
    expect(checkbox.checked, isTrue);
    expect(find.text('1.'), findsOne);
  });

  testWidgets('the callout icon changes through the picker', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add block'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Callout'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // The slash menu seeds the light bulb; the chip swaps it for the picked one.
    expect(find.text('💡'), findsOne);
    await tester.tap(find.bySemanticsLabel('Callout icon'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('🔥'));
    await tester.pump();
    final callout = documentOf(tester).blocks
        .map((block) => block.content)
        .whereType<PlanText>()
        .firstWhere((content) => content.style == PlanTextStyle.callout);
    expect(callout.iconEmoji, '🔥');
  });

  testWidgets('a bookmark asks for its URL and edits it again', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add block'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Bookmark'));
    // The URL dialog opens as part of the same insertion. The dialog's own
    // Save is the target — the workspace chrome has one too.
    await tester.pump(const Duration(milliseconds: 400));
    final dialog = find.byType(ShadDialog);
    await tester.enterText(
      find.descendant(of: dialog, matching: find.byType(EditableText)).last,
      'https://example.com',
    );
    await tester.tap(find.descendant(of: dialog, matching: find.text('Save')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final bookmark = documentOf(
      tester,
    ).blocks.map((block) => block.content).whereType<PlanBookmark>().single;
    expect(bookmark.url, 'https://example.com');
    expect(bookmark.state, PlanBookmarkState.done);
    expect(find.text('https://example.com'), findsOne);

    // The card reopens the dialog with the URL prefilled, and an edit lands.
    await tester.tap(find.bySemanticsLabel('Bookmark URL'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('https://example.com'), findsNWidgets(2));
    final reopened = find.byType(ShadDialog);
    await tester.enterText(
      find.descendant(of: reopened, matching: find.byType(EditableText)).last,
      'https://any.io/changed',
    );
    await tester.tap(
      find.descendant(of: reopened, matching: find.text('Save')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
      documentOf(tester).blocks
          .map((block) => block.content)
          .whereType<PlanBookmark>()
          .single
          .url,
      'https://any.io/changed',
    );
  });

  testWidgets('a typed table(RxC) sizes the table', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Add block'));
    await tester.pump(const Duration(milliseconds: 400));
    final filterField = find
        .descendant(
          of: find.byType(ShadDialog),
          matching: find.byType(EditableText),
        )
        .first;
    await tester.enterText(filterField, 'table(4x2)');
    await tester.pump();
    await tester.tap(find.widgetWithText(DswHoverTap, 'table(4x2)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final rows = documentOf(
      tester,
    ).blocks.where((block) => block.content is PlanTableBlock).toList();
    expect(rows, hasLength(4));
    expect((rows.first.content as PlanTableBlock).isHeader, isTrue);
    for (final row in rows) {
      expect(row.children, hasLength(2));
    }
  });

  testWidgets('the header cells answer column actions', (tester) async {
    File(
      '${root.path}/readme.md',
    ).writeAsStringSync('| A | B |\n| --- | --- |\n| one | two |\n');
    await pump(tester);
    final rowId = documentOf(
      tester,
    ).blocks.firstWhere((block) => block.content is PlanTableBlock).id;
    expect(documentOf(tester).tableColumnCount(rowId), 2);

    await tester.tap(find.bySemanticsLabel('Column actions').first);
    await tester.pump(const Duration(milliseconds: 200));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    await tester.tap(find.text('Insert column right'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    expect(documentOf(tester).tableColumnCount(rowId), 3);
    for (final row in documentOf(
      tester,
    ).blocks.where((block) => block.content is PlanTableBlock)) {
      expect(row.children, hasLength(3));
    }
  });

  testWidgets('the block menu copies and pastes through the clipboard', (
    tester,
  ) async {
    await pump(tester);
    // '# readme', the blank line, 'hello world', and the trailing blank.
    expect(documentOf(tester).blocks.length, 4);
    final menuContext = tester.element(find.byType(PlanBlockEditor));

    // Empty clipboard: Paste is a dimmed row (null tap).
    expect(
      planBlockActions(
        menuContext,
        documentOf(tester),
        documentOf(tester).blocks.first,
      ).where((entry) => entry.label == 'Paste').single.onTap,
      isNull,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    Future<void> openMenu() async {
      await tester.tap(find.bySemanticsLabel('Block actions'));
      await tester.pump(const Duration(milliseconds: 200));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 32));
      }
    }

    // Hover the heading: its gutter shows the actions menu; copy it.
    await gesture.moveTo(tester.getCenter(find.text('readme')));
    await tester.pump();
    await openMenu();
    await tester.tap(find.text('Copy'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }
    // Copy moves nothing; the clipboard holds the heading.
    expect(documentOf(tester).blocks.length, 4);

    // Paste below the paragraph: a fresh-id clone of the copied heading.
    await gesture.moveTo(tester.getCenter(find.text('hello world')));
    await tester.pump();
    await openMenu();
    await tester.tap(find.text('Paste'));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 32));
    }

    final doc = documentOf(tester);
    expect(doc.blocks.length, 5);
    final headingIds = [
      for (final block in doc.blocks)
        if (block.content is PlanText &&
            (block.content as PlanText).text == 'readme')
          block.id,
    ];
    expect(headingIds, hasLength(2));
    expect(headingIds.toSet(), hasLength(2));
  });

  testWidgets('the new faces hold their seats at both amplified steps', (
    tester,
  ) async {
    for (final step in [amplifiedTextStep, nextTextStep]) {
      await pump(tester, step: step);
      await tester.tap(find.text('Add block'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Callout'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.bySemanticsLabel('Callout icon'));
      await tester.pump(const Duration(milliseconds: 400));
      // The emoji grid is the new face. The bookmark dialog measures the same
      // toolbar behind it plus its shad buttons — the button seat is the
      // already-registered ADR-0030 family, so a pass there would say nothing.
      expect(
        textDefects(tester),
        isEmpty,
        reason: 'emoji picker at ${step}x: ${textDefects(tester)}',
      );
      await tester.tap(find.text('🔥'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      // Flush the whole app before the next step pumps a fresh one, or the
      // previous tree's rows linger and the helper's tap goes ambiguous.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }
  });
}
