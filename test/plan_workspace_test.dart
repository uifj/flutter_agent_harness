// The one sentence this file holds: the plan workspace is a real vault — it
// lists only the workspace's markdown files, loads and saves them through the
// actual disk, and refuses to lose unsaved edits on a note switch without
// asking first.
//
// This is the ADR-0007 S3 guard. The vault's whole premise is "the plan library
// IS the workspace", so the file system facts (what gets listed, what a save
// writes, what a discard loses) are the contract — fakes would prove nothing.

import 'dart:io';

import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/plan/plan_workspace.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart' show CodeEditor;
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme, ShadButton;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dsh_plan_');
    File('${root.path}/readme.md').writeAsStringSync('# Readme\n');
    Directory('${root.path}/notes').createSync();
    File('${root.path}/notes/idea.md').writeAsStringSync('An idea\n');
    File('${root.path}/data.txt').writeAsStringSync('not markdown');
  });

  tearDown(() {
    // Windows holds files the vault isolate touched briefly (errno 32) — retry
    // for a moment, then give up: a leftover temp dir must not fail the test.
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        root.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        sleep(const Duration(milliseconds: 25));
      }
    }
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      // The note-switch confirm dialog is a ShadDialog (reads the caller's
      // ShadTheme) — mount the same ancestor main does.
      builder: (context, child) => ShadTheme(
        data: dswShadTheme(Theme.of(context).brightness),
        child: child!,
      ),
      home: Scaffold(body: PlanWorkspace(workspaceRoot: root.path)),
    ),
  );

  /// Hands the event loop real time until [finder] matches — the vault index is
  /// a compute isolate, which a fake-async pump alone never completes.
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  /// Types into the note editor. re_editor is not an `EditableText` — it owns
  /// a `TextInput` delta connection — and pushing values through the test
  /// input service mangles its content; driving the CONTROLLER's text setter
  /// instead is the same edit path the editor itself uses (notify → dirty →
  /// save) without fighting the input pipeline.
  Future<void> typeInto(WidgetTester tester, String text) async {
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller?.text = text;
    await tester.pump();
  }

  /// Retires the editor's cursor-blink timers before the binding checks for
  /// pending ones — same treatment as `editor_tab_test.settle`: unfocus cancels
  /// the periodic blink, and pumping 120ms fires the one-shot while the editor
  /// is still in the tree.
  Future<void> settle(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('lists only the markdown files, folder as the second line', (
    tester,
  ) async {
    await pump(tester);
    await pumpUntil(tester, find.text('readme.md'));

    expect(find.text('readme.md'), findsOneWidget);
    expect(find.text('idea.md'), findsOneWidget);
    expect(find.text('notes'), findsOneWidget);
    expect(find.text('data.txt'), findsNothing);
    await settle(tester);
  });

  /// The inverse of [pumpUntil]: hands the loop real time until [finder]
  /// matches NOTHING — the shape a finished async save needs (the write is real
  /// IO; reading the file before it flushes sees a truncated file).
  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (finder.evaluate().isEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  testWidgets('loads a note and saves the edit back to disk', (tester) async {
    await pump(tester);
    await pumpUntil(tester, find.text('readme.md'));

    await tester.tap(find.text('readme.md'));
    // The note's readAsString is real IO — wait for the editor toolbar.
    await pumpUntil(tester, find.text('Save'));

    // The unsaved chip appears only after a real edit; Save is inert until then.
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    await typeInto(tester, '# Edited\n');
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('Save'));
    // The chip clears only after the write finished — that is the file's
    // "flushed" signal.
    await pumpUntilGone(tester, find.text('Unsaved changes'));
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Edited\n');
    await settle(tester);
  });

  testWidgets('switching notes with unsaved edits asks first', (tester) async {
    await pump(tester);
    await pumpUntil(tester, find.text('readme.md'));

    await tester.tap(find.text('readme.md'));
    // The note's readAsString is real IO — wait for the editor toolbar.
    await pumpUntil(tester, find.text('Save'));
    await typeInto(tester, 'uncommitted');
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);

    // Switch away; the confirm dialog appears, and Cancel keeps the buffer —
    // the unsaved chip survives, and nothing reaches the disk.
    await tester.tap(find.text('idea.md'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved edits?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Readme\n');

    // Again, confirming this time: the buffer is replaced (chip gone) and the
    // note on disk never saw the edits.
    await tester.tap(find.text('idea.md'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ShadButton, 'Discard changes'));
    await pumpUntilGone(tester, find.text('Unsaved changes'));
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Readme\n');
    await settle(tester);
  });
}
