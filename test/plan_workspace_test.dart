// The one sentence this file holds: the plan workspace is a real vault — it
// lists only the workspace's markdown files, saves silently (a trailing
// debounce plus flush points, no save button — ADR-0075), follows agent edits
// to the open note while clean and never overwrites a file that changed
// outside, and asks only when a write could not land.
//
// This is the ADR-0007 S3 guard, reshaped by ADR-0075. The vault's whole
// premise is "the plan library IS the workspace", so the file system facts
// (what gets listed, when a write happens, what the external gate refuses to
// clobber, what a revision bump reloads) are the contract — fakes would prove
// nothing.

import 'dart:io';

import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/l10n/locales.dart';
import 'package:planstar/model/fs_revision.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/blocks/plan_block_editor.dart';
import 'package:planstar/ui/plan/plan_workspace.dart';
import 'amplified_text_probe.dart';
import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart' show CodeEditor;
import 'package:shadcn_ui/shadcn_ui.dart' show ShadSonner, ShadTheme;

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
    Duration autosaveDebounce = const Duration(milliseconds: 100),
    ValueChanged<Future<void> Function()?>? onRegisterFlush,
    AppLocaleId locale = AppLocaleId.en,
    bool withoutWorkspace = false,
  }) => tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale(locale == AppLocaleId.zh ? 'zh' : 'en'),
      theme: dswThemeData(Brightness.light),
      // The stuck-leave confirm dialog is a ShadDialog (reads the caller's
      // ShadTheme), the feedback strip is a ShadSonner, and the copy rides
      // AppLocaleScope — mount the same ancestors main does, so "the user
      // was told" and "the user read it in their language" are assertable.
      builder: (context, child) => AppLocaleScope(
        locale: locale,
        child: ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: ShadSonner(
            child: AmplifiedText(step: scale, child: child!),
          ),
        ),
      ),
      home: Scaffold(
        body: PlanWorkspace(
          workspaceRoot: withoutWorkspace ? null : root.path,
          initialNote: initialNote?.value,
          onNoteConsumed: () => initialNote?.value = null,
          onRegisterFlush: onRegisterFlush,
          autosaveDebounce: autosaveDebounce,
        ),
      ),
    ),
  );

  /// Hands the event loop real time until [finder] matches — the vault index is
  /// a compute isolate, and real-IO futures a fake-async pump alone never
  /// completes. A timeout FAILS: a silent return just relocates the test's
  /// first failure three lines downstream (this file paid that tuition once).
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    fail('pumpUntil timed out waiting for $finder');
  }

  /// The inverse of [pumpUntil]: hands the loop real time until [finder]
  /// matches NOTHING — the shape a finished persist needs when the observable
  /// is a chip disappearing. Times out loudly, same contract as [pumpUntil].
  Future<void> pumpUntilGone(WidgetTester tester, Finder finder) async {
    for (var attempt = 0; attempt < 100; attempt++) {
      if (finder.evaluate().isEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    fail('pumpUntilGone timed out; $finder never went away');
  }

  /// Same as [pumpUntil] but for a file's content: the write is real IO and
  /// lands atomically (tmp+rename), so the needle only appears once the rename
  /// did — reading mid-flight sees the old bytes, never a torn file.
  Future<void> pumpUntilFileContains(
    WidgetTester tester,
    String path,
    String needle,
  ) async {
    for (var attempt = 0; attempt < 200; attempt++) {
      final content = await tester.runAsync(() => File(path).readAsString());
      if (content != null && content.contains(needle)) return;
      await tester.pump();
    }
    fail('"$path" never contained "$needle"');
  }

  /// Taps the mode capsule and waits for the next face's label — the handoff
  /// awaits its flush, whose real IO only completes while runAsync hands the
  /// loop over, so the label is the flush's observable.
  Future<void> cycleMode(
    WidgetTester tester,
    String fromLabel,
    String toLabel,
  ) async {
    await tester.tap(find.text(fromLabel));
    await pumpUntil(tester, find.text(toLabel));
  }

  /// Types into the note editor. re_editor is not an `EditableText` — it owns
  /// a `TextInput` delta connection — and pushing values through the test
  /// input service mangles its content; driving the CONTROLLER's text setter
  /// instead is the same edit path the editor itself uses (notify → dirty →
  /// autosave) without fighting the input pipeline.
  Future<void> typeInto(WidgetTester tester, String text) async {
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    editor.controller?.text = text;
    await tester.pump();
  }

  /// Retires the editor's cursor-blink timers before the binding checks for
  /// pending ones — same treatment as `editor_tab_test.settle`: unfocus cancels
  /// the periodic blink, and pumping 120ms fires the one-shot while the editor
  /// is still in the tree. It ALSO matters before structural swaps
  /// (mode cycle, note switch, unmount): re_editor's mobile branch schedules
  /// an UNCANCELLABLE 100ms `value = true` future per startBlink, so a swap
  /// that unmounts a focused editor leaves a timer pointing at a dead
  /// notifier — letting it burn while the editor is alive is the only remedy.
  /// The 360ms here fires the 100ms test debounce too, which is why tests
  /// that need a PENDING write re-type after the settle.
  Future<void> settle(WidgetTester tester) async {
    FocusManager.instance.primaryFocus?.unfocus();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('edits land on disk after the typing stops — silently', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));

    // No save button anywhere (ADR-0075 ⑥), and an edit in flight shows
    // nothing: the pending state is internal-only.
    expect(find.text('Save'), findsNothing);
    expect(find.text('Changes not written'), findsNothing);

    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Edited\n');
    await tester.pump();
    expect(find.text('Changes not written'), findsNothing);

    // Stop typing; the debounce fires and the write lands.
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntilFileContains(tester, '${root.path}/readme.md', '# Edited');
    // Still nothing on screen: silence IS the contract.
    expect(find.text('Changes not written'), findsNothing);
    await settle(tester);
  });

  testWidgets('switching notes flushes silently — the dialog is gone', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    // Burn the mount's unkillable blink future BEFORE anything re-arms the
    // debounce, so the write below can only be the switch flush's.
    await settle(tester);
    await typeInto(tester, 'uncommitted');
    await tester.pump();

    // The sidebar tree asks for another note (ADR-0073): the host rebuilds
    // the workspace with a new initialNote. The pending edit flushes on the
    // way out — no confirm dialog, no discard. pumpUntil advances no fake
    // time, so the 100ms debounce cannot race the flush here.
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('notes/idea.md'));
    expect(find.text('Unwritten changes'), findsNothing);
    await pumpUntilFileContains(
      tester,
      '${root.path}/readme.md',
      'uncommitted',
    );
    await settle(tester);
  });

  testWidgets('the mode capsule hands the truth across faces', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));

    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Round trip\n');
    // Burn each face's unkillable blink future while that face is still
    // mounted — the swaps below unmount them (see settle's doc).
    await settle(tester);
    // Source → Preview → Edit: the block document rebuilds from the buffer
    // that holds the edit (ADR-0075 ③, preview→edit hop)...
    await cycleMode(tester, 'Source', 'Preview');
    await cycleMode(tester, 'Preview', 'Edit');
    await settle(tester);
    // ...and Edit → Source re-encodes the document — the edit survived the
    // full cycle, which is the handoff contract.
    await cycleMode(tester, 'Edit', 'Source');
    final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    expect(editor.controller!.text, '# Round trip\n');
    await settle(tester);
  });

  testWidgets('the registered flush writes pending edits (close gate)', (
    tester,
  ) async {
    Future<void> Function()? registered;
    final note = ValueNotifier<String?>('readme.md');
    await pump(
      tester,
      initialNote: note,
      onRegisterFlush: (fn) {
        registered = fn;
      },
    );
    await pumpUntil(tester, find.text('Edit'));
    expect(registered, isNotNull);

    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Via flush\n');
    await tester.pump();
    // No debounce wait: the window-close gate writes immediately.
    await tester.runAsync(() => registered!());
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Via flush\n');
    await settle(tester);
  });

  testWidgets('window blur flushes the pending edit', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Blurred\n');
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await pumpUntilFileContains(tester, '${root.path}/readme.md', '# Blurred');
    // Back to resumed so the lifecycle is clean for the next test.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
  });

  testWidgets('unmounting flushes the pending edit', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Orphaned\n');
    // Burn the mount's blink future; the settle also fires the debounce and
    // writes the first text, so the second type re-arms a pending write that
    // only the unmount can deliver.
    await settle(tester);
    await typeInto(tester, '# Orphaned second\n');
    await tester.pump();

    // Entering a plan extension view swaps the center pane — the workspace
    // unmounts, and the pending edit leaves with it (ADR-0075 ②).
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('en'),
        home: SizedBox.shrink(),
      ),
    );
    await pumpUntilFileContains(
      tester,
      '${root.path}/readme.md',
      '# Orphaned second',
    );
  });

  testWidgets('an externally changed file is never overwritten', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));

    // The agent (or git) rewrites the file behind the editor's back — before
    // any local edit, so the gate baseline is the stale one.
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent was here\n');
    });
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, 'local edits');
    await tester.pump(const Duration(milliseconds: 150));

    // The gate refuses the write, says so once, and marks the note stuck.
    await pumpUntil(
      tester,
      find.text('The note changed on disk — autosave paused.'),
    );
    expect(find.text('Changes not written'), findsOneWidget);
    expect(
      File('${root.path}/readme.md').readAsStringSync(),
      '# Agent was here\n',
    );
    await settle(tester);
  });

  testWidgets('the editor follows agent edits to the open note', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));

    // The agent rewrites the open note and the tools bump the revision —
    // AppFlowy's remote-apply, localized: the editor is a live view of the
    // file while the buffer is clean.
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent chapter\n');
      bumpFsRevision();
    });
    await pumpUntil(tester, find.text('Agent chapter'));

    expect(find.text('Changes not written'), findsNothing);
    expect(
      File('${root.path}/readme.md').readAsStringSync(),
      '# Agent chapter\n',
    );
    await settle(tester);
  });

  testWidgets('a touch without a content change does not reload', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    final before = tester
        .widget<PlanBlockEditor>(find.byType(PlanBlockEditor))
        .document;

    // Same bytes, new mtime (a git checkout, a touch) — adopting the stat is
    // enough; rebuilding the document would throw away the undo stack.
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Readme\n');
      bumpFsRevision();
    });
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    final after = tester
        .widget<PlanBlockEditor>(find.byType(PlanBlockEditor))
        .document;
    expect(identical(before, after), isTrue);
    await settle(tester);
  });

  testWidgets('agent edits while dirty go straight to stuck', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, 'local edits');
    await tester.pump();

    // No debounce wait: the revision bump itself surfaces the conflict.
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent was here\n');
      bumpFsRevision();
    });
    await pumpUntil(
      tester,
      find.text('The note changed on disk — autosave paused.'),
    );
    expect(find.text('Changes not written'), findsOneWidget);
    expect(
      File('${root.path}/readme.md').readAsStringSync(),
      '# Agent was here\n',
    );
    await settle(tester);
  });

  testWidgets('a vanished note closes instead of resurrecting', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));

    await tester.runAsync(() async {
      File('${root.path}/readme.md').deleteSync();
      bumpFsRevision();
    });
    await pumpUntil(tester, find.text('Pick a markdown file from the tree'));
    expect(find.text('The note was removed on disk — closed.'), findsOneWidget);
    expect(File('${root.path}/readme.md').existsSync(), isFalse);
    await settle(tester);
  });

  testWidgets('a reload rebinds the source bridge — edits still autosave', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await settle(tester);
    // The agent's write swaps in a fresh controller; the Source face's dirty
    // bridge must follow it, or every edit after a reload would never save.
    // Asserted on the CONTROLLER — find.text cannot see re_editor's
    // rendering, and the controller is the face's truth anyway.
    var ctrl = '';
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# From agent\n');
      bumpFsRevision();
    });
    for (var attempt = 0; attempt < 100; attempt++) {
      ctrl = tester
          .widget<CodeEditor>(find.byType(CodeEditor))
          .controller!
          .text;
      if (ctrl.contains('From agent')) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(ctrl, contains('From agent'));
    await typeInto(tester, '# After reload\n');
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntilFileContains(
      tester,
      '${root.path}/readme.md',
      '# After reload',
    );
    await settle(tester);
  });

  testWidgets('a fresh empty note opens ready to type', (tester) async {
    // The tree's create flow writes an empty file (plan_vault_tree). Anytype
    // lands every new object on an editable surface, AppFlowy's new page is
    // click-and-type from the first frame — an empty note must be the same.
    File('${root.path}/new note.md').writeAsStringSync('');
    final note = ValueNotifier<String?>('new note.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.byType(PlanBlockEditor));
    await tester.enterText(find.byType(EditableText).first, 'first words');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntilFileContains(
      tester,
      '${root.path}/new note.md',
      'first words',
    );
    await settle(tester);
  });

  testWidgets('a three-face round trip keeps the document — and its undo', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.byType(PlanBlockEditor));
    // Edit in the block editor, then glance at Source and Preview before
    // coming back. Nothing was changed outside the document, so the document
    // — and its undo history — must survive the tour (Obsidian's face toggle
    // never resets undo; a glance is not an edit).
    await tester.enterText(find.byType(EditableText).first, 'readme edited');
    await tester.pump();
    final before = tester
        .widget<PlanBlockEditor>(find.byType(PlanBlockEditor))
        .document;
    await cycleMode(tester, 'Edit', 'Source');
    await settle(tester);
    await cycleMode(tester, 'Source', 'Preview');
    await settle(tester);
    await cycleMode(tester, 'Preview', 'Edit');
    final after = tester
        .widget<PlanBlockEditor>(find.byType(PlanBlockEditor))
        .document;
    expect(identical(before, after), isTrue);
    // The undo stack came around too: one undo reverts the edit. Two pumps —
    // the undo notify rebuilds the bridge on the first frame and the field's
    // controller sync lands on the second (plan_blocks_test's two-frame rule).
    after.undo();
    await tester.pump();
    await tester.pump();
    expect(find.text('Readme'), findsOne);
    await settle(tester);
  });

  testWidgets('reverting to the saved content clears the stuck state', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, 'local edits');
    await tester.pump();

    // The agent rewrites the file; the editor goes stuck.
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent was here\n');
      bumpFsRevision();
    });
    await pumpUntil(tester, find.text('Changes not written'));

    // The user reverts their own edit (back to the opened text): there is
    // nothing of ours left to write, so the conflict dissolves — the chip
    // clears and leaving the note needs no dialog.
    await typeInto(tester, '# Readme\n');
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntilGone(tester, find.text('Changes not written'));

    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('notes/idea.md'));
    expect(find.text('Unwritten changes'), findsNothing);
    // The agent's version is still on the disk — untouched.
    expect(
      File('${root.path}/readme.md').readAsStringSync(),
      '# Agent was here\n',
    );
    await settle(tester);
  });

  testWidgets('the preview face follows an agent reload', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await settle(tester);
    await cycleMode(tester, 'Source', 'Preview');
    await settle(tester);

    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Fresh from agent\n');
      bumpFsRevision();
    });
    await pumpUntil(tester, find.text('Fresh from agent'));
    await settle(tester);
  });

  testWidgets('zh: the whole stuck chain speaks Chinese', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note, locale: AppLocaleId.zh);
    await pumpUntil(tester, find.byType(PlanBlockEditor));
    await pumpUntil(tester, find.text('编辑'));

    await cycleMode(tester, '编辑', '源码');
    await typeInto(tester, '本地修改');
    await tester.pump();

    // The agent rewrites the file mid-edit: feedback, chip and the leave
    // dialog must all speak the user's language — a raw key or English copy
    // inside a Chinese frame is exactly what the dictionaries exist to
    // prevent (and what translate()'s fallback chain hides).
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent was here\n');
      bumpFsRevision();
    });
    // Same queued-sync window as the reload test.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await pumpUntil(tester, find.text('笔记在盘上已被外部修改，自动保存已暂停。'));
    expect(find.text('修改未写入盘'), findsOneWidget);

    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note, locale: AppLocaleId.zh);
    await pumpUntil(tester, find.text('存在未写入的修改'));
    expect(find.text('丢弃并离开'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('readme.md'), findsOneWidget);

    await settle(tester);
  });

  testWidgets('zh: a vault with no workspace answers with guidance', (
    tester,
  ) async {
    await pump(tester, locale: AppLocaleId.zh, withoutWorkspace: true);
    expect(find.text('请先选择工作区文件夹——企划库就是工作区'), findsOneWidget);
  });

  testWidgets('leaving a stuck note asks before discarding', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent was here\n');
    });
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, 'local edits');
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntil(
      tester,
      find.text('The note changed on disk — autosave paused.'),
    );

    // Cancel: stay on the note, buffer intact.
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Unwritten changes'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('readme.md'), findsOneWidget);
    expect(find.text('notes/idea.md'), findsNothing);

    await settle(tester);

    // The consume handed the token back; the real host rebuilds with null
    // (consumeOpenNote notifies). Mirror that, or the SAME second request
    // would be swallowed by the changed-config guard (ADR-0073).
    note.value = null;
    await pump(tester, initialNote: note);

    // Again, confirming this time: the note switches and the disk keeps the
    // external version — the local edits are gone, as the dialog said.
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Unwritten changes'));
    await tester.tap(find.text('Discard & leave'));
    await pumpUntil(tester, find.text('notes/idea.md'));
    expect(
      File('${root.path}/readme.md').readAsStringSync(),
      '# Agent was here\n',
    );
    await settle(tester);
  });

  testWidgets('a cancelled open hands the token back for the next request', (
    tester,
  ) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await tester.runAsync(() async {
      File('${root.path}/readme.md').writeAsStringSync('# Agent was here\n');
    });
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, 'local edits');
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntil(
      tester,
      find.text('The note changed on disk — autosave paused.'),
    );

    // Ask for another note; the stuck dialog appears; Cancel. The workspace
    // must hand the token back ITSELF — the real host's consumeOpenNote
    // clears and notifies, so the harness's mirror (onNoteConsumed) drops
    // the value. A silent token left the same second request to be
    // swallowed by the changed-config guard forever (the didUpdateWidget
    // path never consumed — the ADR-0073 trap, fixed on the initState path
    // only).
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Unwritten changes'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(note.value, isNull, reason: 'the token came back on cancel');

    // The consume notifies the real host, which rebuilds with a null token
    // BEFORE the next click lands — push that frame through, then ask for
    // the same note again: the guard sees a fresh change and the dialog
    // reappears. The tree is not a dead button.
    await pump(tester, initialNote: note);
    // Burn the source editor's unkillable blink future while it is still
    // mounted (settle's doc): the confirm below swaps it out.
    await settle(tester);
    note.value = 'notes/idea.md';
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Unwritten changes'));
    await tester.tap(find.text('Discard & leave'));
    await pumpUntil(tester, find.text('notes/idea.md'));
    await settle(tester);
  });

  testWidgets('a failed write stays stuck and says so', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));

    // dart:io has no chmod; a directory squatting on the tmp path makes the
    // writeAsString throw — a deterministic IO failure with the gate clean.
    Directory('${root.path}/readme.md.tmp').createSync();
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Doomed\n');
    await tester.pump(const Duration(milliseconds: 150));

    await pumpUntil(tester, find.text('Saving the note failed.'));
    expect(find.text('Changes not written'), findsOneWidget);
    expect(File('${root.path}/readme.md').readAsStringSync(), '# Readme\n');
    await settle(tester);
  });

  testWidgets('the write is atomic — no tmp residue', (tester) async {
    final note = ValueNotifier<String?>('readme.md');
    await pump(tester, initialNote: note);
    await pumpUntil(tester, find.text('Edit'));
    await cycleMode(tester, 'Edit', 'Source');
    await typeInto(tester, '# Atomic\n');
    await tester.pump(const Duration(milliseconds: 150));
    await pumpUntilFileContains(tester, '${root.path}/readme.md', '# Atomic');

    final residue = root
        .listSync()
        .where((entry) => entry.path.endsWith('.tmp'))
        .toList();
    expect(residue, isEmpty);
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
      await pumpUntil(tester, find.text('Edit'));
      expect(textDefects(tester), isEmpty, reason: 'an open note');
      await settle(tester);
    });
  }
}
