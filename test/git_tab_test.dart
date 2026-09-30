// The source-control tab, over a fake git.
//
// What is worth a widget test here is the wiring the pure parser tests cannot
// see: that status rows land in the right sections and open the right diff
// tabs, that the stage/unstage/commit gestures send their commands and
// refresh, that a non-repo says so, and that destructive actions only run
// behind their confirm dialog.
//
// It is also the only place this tab is pumped *with a repo*: the workbench
// walk opens it over a bare temp directory, so it can never see a branch name,
// a status badge, or the two menus those make room for — which is what the
// amplified-text face at the bottom of this file measures.

import 'dart:io';

import 'package:agent_harness/model/sidebar_tab.dart';
import 'package:agent_harness/state/workbench_controller.dart';
import 'package:agent_harness/state/workbench_store.dart';
import 'package:agent_harness/ui/primitives/menu.dart' show DswSelect;
import 'package:agent_harness/ui/workbench/tabs/git_tab.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme, ShadButton, ShadInput;

import 'amplified_text_probe.dart';
import 'clipboard_probe.dart';
import 'fake_git.dart';

/// What a field holds. A `ShadInput` renders its text through an `EditableText`
/// and not a `Text`, so `find.text`/`widgetWithText` cannot see the draft at
/// all — the controller the field is built on is the one place the string is.
/// (ADR-0036 batch B7 moved the field off Material.)
String fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  late DirectoryFixture support;
  late WorkbenchController workbench;
  late FakeGit fake;

  setUp(() {
    support = DirectoryFixture();
    workbench = WorkbenchController(store: WorkbenchStore.open(support.dir));
    workbench.workspaceRoot = support.path;
    // '' rather than the strict default: every gesture the panel makes —
    // stage, commit, checkout, discard — is a command whose *response* the
    // panel does not read, so a per-test stub would be noise; the reads it
    // does parse (status, branches, log) are stubbed by [FakeGit.stubRepo]
    // and stay asserted through the UI.
    fake = FakeGit(unknownResponse: '')..stubRepo(root: support.path);
  });

  tearDown(() {
    workbench.dispose();
    support.dispose();
  });

  Future<void> pumpTab(WidgetTester tester, {double step = 1.0}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: dswThemeData(Brightness.light),
          // Mirrors main's MaterialApp.builder: the confirm dialog is a
          // ShadDialog, which reads ShadTheme off the caller context.
          builder: (context, child) => ShadTheme(
            data: dswShadTheme(Theme.of(context).brightness),
            child: child!,
          ),
          home: Scaffold(
            body: AmplifiedText(
              step: step,
              child: GitHost(
                runner: fake.runner,
                child: GitTab(workbench: workbench, tab: SidebarTab.git),
              ),
            ),
          ),
        ),
      );

  /// The tab's futures are sync-resolving fakes, so a frame is enough for each
  /// hop; two covers the open→refresh chain.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  testWidgets('lists staged and unstaged rows under their sections', (
    tester,
  ) async {
    await pumpTab(tester);
    await settle(tester);

    expect(find.text('STAGED (1)'), findsOneWidget);
    expect(find.text('UNSTAGED (2)'), findsOneWidget);
    // 'new.txt' is untracked and lands with the unstaged, badge '?'.
    expect(find.text('staged.txt'), findsOneWidget);
    expect(find.text('unstaged.txt'), findsOneWidget);
    expect(find.text('new.txt'), findsOneWidget);
    expect(find.text('No changes'), findsNothing);
    // The history renders its one stubbed row.
    expect(find.text('subject line'), findsOneWidget);
  });

  testWidgets('a row click opens the diff tab for that path and side', (
    tester,
  ) async {
    await pumpTab(tester);
    await settle(tester);

    await tester.tap(find.text('unstaged.txt'));
    await settle(tester);

    final tab = workbench.state.tabById(
      'diff:worktree:tree:${support.path}/unstaged.txt',
    );
    expect(tab, isNotNull);
    final diff = tab!.diff;
    expect(diff, isA<WorktreeDiff>());
    expect((diff as WorktreeDiff).staged, isFalse);
    // Untracked paths have no `git diff` to ask for; the whole file is added.
    expect((diff).untracked, isFalse);
  });

  testWidgets('an untracked row opens as an untracked diff', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    await tester.tap(find.text('new.txt'));
    await settle(tester);

    final tab = workbench.state.tabById(
      'diff:worktree:tree:${support.path}/new.txt',
    );
    expect((tab!.diff as WorktreeDiff).untracked, isTrue);
  });

  testWidgets('a history row click opens the commit diff tab', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    await tester.tap(find.text('subject line'));
    await settle(tester);

    final tab = workbench.state.tabById('diff:commit:fullhash123');
    expect(tab, isNotNull);
    expect((tab!.diff as CommitDiff).subject, 'subject line');
  });

  testWidgets('stage all and unstage all send their commands', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    await tester.tap(find.text('Stage all'));
    await settle(tester);
    expect(fake.commands, contains('add -A'));

    await tester.tap(find.text('Unstage all'));
    await settle(tester);
    expect(fake.commands, contains('reset -q'));
  });

  testWidgets('a row stage button stages that one path', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    // The unstaged rows carry a stage affordance at their trailing edge. The
    // row's own Container is the anchor — not a MouseRegion, because the
    // closest MouseRegion to the path text is its Tooltip's, which wraps only
    // the text half of the row.
    final row = find
        .ancestor(
          of: find.text('unstaged.txt'),
          matching: find.byType(Container),
        )
        .first;
    final button = find.descendant(
      of: row,
      matching: find.byIcon(LucideIcons.git_branch),
    );
    await tester.tap(button);
    await settle(tester);
    expect(fake.commands, contains('add -A -- unstaged.txt'));
  });

  testWidgets('commit sends the message and clears the box', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    await tester.enterText(find.byType(ShadInput), 'a committed message');
    await settle(tester);
    await tester.tap(find.text('Commit'));
    await settle(tester);

    expect(fake.commands, contains('commit -m a committed message'));
    expect(fieldText(tester), isEmpty);
  });

  testWidgets('the branch selector switches branches', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    // The branch chip is the panel's one `DswSelect`; it is named by type
    // rather than by the branch it currently shows, because which branch that
    // is belongs to the fake repository, not to this assertion.
    await tester.tap(find.byType(DswSelect<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('dev'));
    await settle(tester);

    expect(fake.commands, contains('checkout dev'));
  });

  testWidgets('a failing status shows the error text', (tester) async {
    fake.failures.add('status --porcelain=v1 -z --untracked-files=all');
    await pumpTab(tester);
    await settle(tester);

    expect(
      find.text('boom: status --porcelain=v1 -z --untracked-files=all'),
      findsOneWidget,
    );
  });

  testWidgets('outside a work tree the panel says so', (tester) async {
    fake.failures.add('rev-parse --show-toplevel');
    await pumpTab(tester);
    await settle(tester);

    expect(find.text('This directory is not a git repository'), findsOneWidget);
  });

  testWidgets('discard asks first, then sends the command', (tester) async {
    await pumpTab(tester);
    await settle(tester);

    // Right-click an unstaged row. The menu's entrance is a fade, and a
    // fully-transparent widget does not hit-test — the items only become
    // tappable once that animation has settled.
    await tester.tap(find.text('unstaged.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    // The menu offers discard for tracked files. The item's tap only returns
    // from `await showMenu(...)` once the menu has finished leaving the screen,
    // so the dialog below needs the exit animation settled first.
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    // The confirm dialog; cancelling must not touch git.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fake.commands, isNot(contains('checkout -- unstaged.txt')));

    // Again, confirming this time.
    await tester.tap(find.text('unstaged.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ShadButton, 'Discard changes'));
    await tester.pumpAndSettle();
    expect(fake.commands, contains('checkout -- unstaged.txt'));
  });

  testWidgets('the file menu copies the relative path', (tester) async {
    // The probe answers the clipboard channel — the real messenger never
    // would, and the copy's await would hang the test.
    final clipboard = ClipboardProbe(tester.binding.defaultBinaryMessenger);
    await pumpTab(tester);
    await settle(tester);

    await tester.tap(find.text('staged.txt'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Copy relative path'));
    // The copy runs after the menu finishes leaving the screen — the same
    // `await showMenu(...)` chain as the discard dialog.
    await tester.pumpAndSettle();

    expect(clipboard.text, 'staged.txt');
  });

  // The panel's own seats, and the two menus that only exist once opened.
  //
  // The workbench walk already pumps this tab, but over a directory that is
  // not a repo: no branch, no rows, nothing with a label to cut. The fake
  // supplies both, which is what makes the branch chip (26px, one 12px line)
  // and the row menu measurable.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the panel and its two menus keep their labels ($label)', (
        tester,
      ) async {
        Future<void> close() async {
          // A menu left on screen covers the next face, and a route nobody
          // popped leaves its timer armed for the binding to fail on.
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
        }

        await pumpTab(tester, step: step);
        await settle(tester);
        expect(find.text('staged.txt'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the source panel');

        await tester.tap(find.byType(DswSelect<String>));
        await tester.pumpAndSettle();
        expect(find.text('dev'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the branch menu');
        await close();

        await tester.tap(find.text('staged.txt'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        expect(find.text('Copy relative path'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the row menu');
        await close();

        // The destructive confirm the row menu opens (`showConfirmDialog`, the
        // one shell four call sites route through). It is a route, so until the
        // step moved above the Navigator it had never been laid out amplified:
        // its title, description and two buttons are the last chrome in this
        // panel nobody had measured.
        await tester.tap(find.text('unstaged.txt'), buttons: kSecondaryButton);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Discard changes'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the confirm dialog');
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('Cancel'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// The temp directory the workbench store writes to, and the fake repo root.
class DirectoryFixture {
  DirectoryFixture()
    : dir = Directory.systemTemp.createTempSync('dsh_git_tab_');

  final Directory dir;

  String get path => dir.path;

  void dispose() => dir.deleteSync(recursive: true);
}
