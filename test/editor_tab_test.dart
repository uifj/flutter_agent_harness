// The editor's chrome: the path bar, the preview toggle, and the refresh.
//
// The editor's buffer mechanics (highlighting, the dirty flag, Cmd-S) belong
// to re_editor and are not re-tested here. What belongs to THIS tab is the bar
// above the buffer: the path shown relative to the workspace, the preview
// toggle that only a markdown file earns, the reload that re-reads the disk,
// and the failure notices for the files that cannot be opened at all. Those
// are the tab's own contract with the disk, behind the same guard the tools
// use, so they get pumped against a real directory.
//
// `pumpUntil` with `runAsync` between pumps is the idiom the workbench suite
// established: a `dart:io` future never completes inside a fake-async zone on
// its own, so the test hands the event loop real time until the load lands.

import 'dart:io';

import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:agent_harness/ui/workbench/tabs/editor_tab.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/assistant_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  late Directory support;
  late WorkbenchController workbench;

  setUp(() {
    support = Directory.systemTemp.createTempSync('dsh_editor_tab_');
    workbench = WorkbenchController(store: WorkbenchStore.open(support));
  });

  tearDown(() {
    workbench.dispose();
    support.deleteSync(recursive: true);
  });

  /// A canonical workspace — resolved, because the guard canonicalises its
  /// root and the system temp directory is itself a symlink on macOS.
  Directory workspace() {
    final root = Directory('${support.path}/work')..createSync();
    return Directory(root.resolveSymbolicLinksSync());
  }

  Future<void> pumpTab(WidgetTester tester, SidebarTab tab) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          home: Scaffold(
            body: EditorTab(workbench: workbench, tab: tab),
          ),
        ),
      );

  /// Hands the event loop real time until [finder] matches — the load is a
  /// `dart:io` future, which a fake-async pump alone never completes.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// Fires re_editor's mobile-branch blink one-shot — `Future.delayed(100ms)`,
  /// posted on focus because `defaultTargetPlatform` is android under
  /// `flutter test` — while the blink's controller is still alive. It must run
  /// soon after the editor gains focus: once the editor is disposed, a preview
  /// toggle does exactly that, the same callback would land on a disposed
  /// controller, and that is a crash, not a cleanup.
  Future<void> retireBlink(WidgetTester tester) =>
      tester.pump(const Duration(milliseconds: 120));

  /// Retires the editor's cursor-blink timers before the binding checks for
  /// pending ones: the editor autofocuses, and a focused cursor blinks on a
  /// timer that otherwise outlives the test. Unfocus cancels the periodic one;
  /// the clock fires the one-shot above on an editor still in the tree.
  Future<void> settle(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await retireBlink(tester);
  }

  group('the path bar', () {
    testWidgets('shows the path relative to the workspace', (tester) async {
      final root = workspace();
      Directory('${root.path}/lib').createSync();
      final file = File('${root.path}/lib/main.dart')
        ..writeAsStringSync('void main() {}\n');
      workbench.workspaceRoot = root.path;

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byType(CodeEditor));

      expect(find.text('lib/main.dart'), findsOneWidget);
      await settle(tester);
    });

    testWidgets('an absolute path when there is no workspace', (tester) async {
      final file = File('${support.path}/loose.md')
        ..writeAsStringSync('# loose\n');
      // No workspaceRoot: the guard is absent, but the bar still owes the tab
      // a path — the whole path.

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byIcon(LucideIcons.refresh_cw));

      expect(find.text(file.path), findsOneWidget);
      await settle(tester);
    });
  });

  group('the preview toggle', () {
    testWidgets('a markdown file previews and comes back to the source', (
      tester,
    ) async {
      final root = workspace();
      final file = File('${root.path}/notes.md')
        ..writeAsStringSync('# Title\n\nBody.');
      workbench.workspaceRoot = root.path;

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byType(CodeEditor));
      // The editor this test is about to dispose still owns a pending blink
      // one-shot; retire it now, while its controller is alive.
      await retireBlink(tester);

      // Source first — that is what a save edits.
      expect(find.byType(AssistantMarkdown), findsNothing);
      expect(find.byType(CodeEditor), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.eye));
      await tester.pump();
      expect(find.byType(AssistantMarkdown), findsOneWidget);
      expect(find.text('Title', findRichText: true), findsOneWidget);
      expect(find.byType(CodeEditor), findsNothing);

      // And back: the eye is a toggle, not a one-way door.
      await tester.tap(find.byIcon(LucideIcons.eye));
      await tester.pump();
      expect(find.byType(CodeEditor), findsOneWidget);
      await settle(tester);
    });

    testWidgets('a source file earns no eye at all', (tester) async {
      final root = workspace();
      final file = File('${root.path}/main.dart')
        ..writeAsStringSync('void main() {}\n');
      workbench.workspaceRoot = root.path;

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byType(CodeEditor));

      expect(find.byIcon(LucideIcons.eye), findsNothing);
      // The reload is still there: a source file cannot be previewed, but it
      // can always be stale.
      expect(find.byIcon(LucideIcons.refresh_cw), findsOneWidget);
      await settle(tester);
    });
  });

  group('the reload', () {
    testWidgets('re-reads the file the disk now holds', (tester) async {
      final root = workspace();
      final file = File('${root.path}/notes.md')
        ..writeAsStringSync('# Before\n');
      workbench.workspaceRoot = root.path;

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byType(CodeEditor));
      // Retire the blink one-shot before the preview toggle below disposes
      // the editor that owns it.
      await retireBlink(tester);

      // The outside world rewrites the file under the tab.
      file.writeAsStringSync('# After\n');
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );

      await tester.tap(find.byIcon(LucideIcons.refresh_cw));
      await tester.pump();

      // The preview is the readable mirror of the buffer.
      await tester.tap(find.byIcon(LucideIcons.eye));
      await pumpUntil(tester, find.text('After', findRichText: true));
      expect(find.text('Before', findRichText: true), findsNothing);
      await settle(tester);
    });
  });

  group('the failures', () {
    testWidgets('a deleted file says so, and keeps its path bar', (
      tester,
    ) async {
      final root = workspace();
      final file = File('${root.path}/gone.md')..writeAsStringSync('# gone\n');
      workbench.workspaceRoot = root.path;
      file.deleteSync();

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byIcon(LucideIcons.refresh_cw));

      // The bar explains WHICH tab is complaining; the body says why.
      expect(find.text('gone.md'), findsOneWidget);
      expect(find.byType(CodeEditor), findsNothing);
    });

    testWidgets('a binary file is refused, not garbled', (tester) async {
      final root = workspace();
      final file = File('${root.path}/blob.bin')
        ..writeAsBytesSync([0, 159, 146, 150, 0, 1]);
      workbench.workspaceRoot = root.path;

      await pumpTab(tester, SidebarTab.editor(file.path));
      await pumpUntil(tester, find.byIcon(LucideIcons.refresh_cw));

      expect(find.byType(CodeEditor), findsNothing);
      expect(find.byType(AssistantMarkdown), findsNothing);
    });
  });
}
