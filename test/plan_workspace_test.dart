// The one sentence this file holds: the plan workspace is a real vault — it
// lists only the workspace's markdown files, loads and saves them through the
// actual disk, and refuses to lose unsaved edits on a note switch without
// asking first.
//
// This is the ADR-0007 S3 guard. The vault's whole premise is "the plan library
// IS the workspace", so the file system facts (what gets listed, what a save
// writes, what a discard loses) are the contract — fakes would prove nothing.

import 'dart:io';

import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/plan_workspace.dart';
import 'amplified_text_probe.dart';
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

  Future<void> pump(
    WidgetTester tester, {
    ValueNotifier<String?>? initialNote,
    double scale = 1.0,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      // The note-switch confirm dialog is a ShadDialog (reads the caller's
      // ShadTheme) — mount the same ancestor main does. The text step goes
      // with it, above the Navigator, so the dialog and any menu are laid
      // out at the step the walk claims to be measuring.
      builder: (context, child) => ShadTheme(
        data: dswShadTheme(Theme.of(context).brightness),
        child: AmplifiedText(step: scale, child: child!),
      ),
      home: Scaffold(
        body: PlanWorkspace(
          workspaceRoot: root.path,
          initialNote: initialNote?.value,
          onNoteConsumed: () => initialNote?.value = null,
        ),
      ),
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

  /// Switches the note surface to Source mode: the block editor owns Edit,
  /// and these two tests pin the raw-buffer save contract, which lives on the
  /// Source face (the block editor's own encode-on-save has its test in
  /// `plan_blocks_test.dart`).
  Future<void> gotoSource(WidgetTester tester) async {
    // The capsule shows the CURRENT face and cycles Edit → Source → Preview;
    // from the freshly opened note one tap reaches Source.
    await tester.tap(find.text('Edit'));
    await tester.pump();
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

  testWidgets('opens the initial note and saves the edit back to disk', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Save'));

    // The unsaved chip appears only after a real edit; Save is inert until then.
    expect(find.text('Unsaved changes'), findsNothing);
    expect(find.text('Save'), findsOneWidget);

    await gotoSource(tester);
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
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Save'));
    await gotoSource(tester);
    await typeInto(tester, 'uncommitted');
    await tester.pump();
    expect(find.text('Unsaved changes'), findsOneWidget);

    // The sidebar tree asks for another note (ADR-0073): the host rebuilds
    // the workspace with a new initialNote. The confirm dialog appears, and
    // Cancel keeps the buffer — nothing reaches the disk.
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    // _openPath reads the note through real IO — wait for the dialog.
    await pumpUntil(tester, find.text('Discard unsaved edits?'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Readme\n');

    // Unfocus BEFORE the swap: the old editor's blink timer is owned by its
    // editor state, and firing one after the swap+dispose lands on a dead
    // object (editor_tab's settle does the same before closing tabs).
    await settle(tester);

    // The consume handed the token back; the real host rebuilds with null
    // (consumeOpenNote notifies). Mirror that, or the widget would still hold
    // 'notes/idea.md' and the SAME second request would be swallowed by the
    // changed-config guard.
    note.value = null;
    await pump(tester, initialNote: note);

    // Again, confirming this time: the buffer is replaced (chip gone) and the
    // note on disk never saw the edits.
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Discard unsaved edits?'));
    await tester.tap(find.widgetWithText(ShadButton, 'Discard changes'));
    await pumpUntilGone(tester, find.text('Unsaved changes'));
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Readme\n');
    await settle(tester);
  });

  // ADR-0017 S3, now on the editor alone: the tree's own measurements moved
  // to `plan_vault_tree_test.dart` with the tree (ADR-0073).
  for (final (label, step) in const [
    ('1.8x', amplifiedTextStep),
    ('2.2x', nextTextStep),
  ]) {
    testWidgets('the editor survives amplified text ($label)', (tester) async {
      final note = ValueNotifier<String?>('readme.md');
      await pump(tester, initialNote: note, scale: step);
      await pumpUntil(tester, find.text('Save'));
      expect(textDefects(tester), isEmpty, reason: 'an open note');
      await settle(tester);
    });
  }
}
