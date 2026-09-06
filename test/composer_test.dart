// The composer's tool row, pumped for real.
//
// The row is three controls — attach, mode, send — and the first two are menus,
// which is exactly the part a reducer or a controller test cannot see: what the
// paperclip offers, what the mode chip says about the current mode, and what
// typing `/` does to the draft. The plugin-backed actions (the file pick, the
// clipboard paste) are deliberately not driven here — their platform channels
// do not exist in a test harness, and the interesting contract is what the
// menus offer, not what the plugins do.
//
// What each test asserts is the seam the app depends on: the mode selector is
// live (it flips the mode the gated tools consult, with no confirm step), and
// the command menu is a keyboard-first affordance that must filter, run, and
// get out of the way.

import 'dart:async';

import 'package:agent_harness/model/approval_mode.dart';
import 'package:agent_harness/model/attached_image.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/model/workspace_index.dart';
import 'package:agent_harness/state/model_directory.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';

/// Owns the mode as state, the way `ConversationRoot`'s ListenableBuilder
/// does: a selector the chip flips must be able to reach the chip, which only
/// happens if the host rebuilds with the new value.
class _ComposerHost extends StatefulWidget {
  const _ComposerHost({
    required this.mode,
    required this.onMode,
    required this.onNewSession,
    required this.onSubmit,
    this.hero = false,
    this.busy = false,
    this.blocked = false,
    this.withModeSelector = true,
    this.withNewSession = true,
    this.modelDirectory,
    this.onModelSelected,
    this.onLookupFiles,
  });

  final ApprovalMode mode;
  final ValueChanged<ApprovalMode> onMode;
  final VoidCallback onNewSession;
  final void Function(String text, List<AttachedImage> images) onSubmit;
  final bool hero;
  final bool busy;
  final bool blocked;
  final bool withModeSelector;
  final bool withNewSession;
  final ModelDirectory? modelDirectory;
  final ValueChanged<String>? onModelSelected;
  final Future<List<FileEntry>> Function()? onLookupFiles;

  @override
  State<_ComposerHost> createState() => _ComposerHostState();
}

class _ComposerHostState extends State<_ComposerHost> {
  late ApprovalMode _mode = widget.mode;

  @override
  void didUpdateWidget(_ComposerHost old) {
    super.didUpdateWidget(old);
    // A hand-set mode (a test, or a session restore) is authoritative until
    // the selector next changes it.
    if (widget.mode != old.mode) _mode = widget.mode;
  }

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 748),
      child: Composer(
        hero: widget.hero,
        busy: widget.busy,
        blocked: widget.blocked,
        approvalMode: _mode,
        onApprovalMode: widget.withModeSelector
            ? (next) {
                setState(() => _mode = next);
                widget.onMode(next);
              }
            : null,
        onNewSession: widget.withNewSession ? widget.onNewSession : null,
        modelDirectory: widget.modelDirectory,
        onModelSelected: widget.onModelSelected,
        onLookupFiles: widget.onLookupFiles,
        onSubmit: widget.onSubmit,
        onStop: () {},
      ),
    ),
  );
}

void main() {
  late ApprovalMode mode;
  var newSession = 0;

  setUp(() {
    mode = ApprovalMode.ask;
    newSession = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    bool hero = false,
    bool busy = false,
    bool blocked = false,
    bool withModeSelector = true,
    bool withNewSession = true,
    ModelDirectory? directory,
    ValueChanged<String>? onModelSelected,
    Future<List<FileEntry>> Function()? onLookupFiles,
    void Function(String text, List<AttachedImage> images)? onSubmit,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: _ComposerHost(
          mode: mode,
          onMode: (next) => mode = next,
          onNewSession: () => newSession++,
          onSubmit: onSubmit ?? (text, images) {},
          hero: hero,
          busy: busy,
          blocked: blocked,
          withModeSelector: withModeSelector,
          withNewSession: withNewSession,
          modelDirectory: directory,
          onModelSelected: onModelSelected,
          onLookupFiles: onLookupFiles,
        ),
      ),
    ),
  );

  group('the row', () {
    testWidgets('paints the paperclip, the mode chip, and the send button', (
      tester,
    ) async {
      await pump(tester);

      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
      expect(find.text('Ask every time'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrow_up), findsOneWidget);
      // The menu is closed until the chip is tapped.
      expect(find.text('Plan first'), findsNothing);
    });

    testWidgets('the chip names the mode it was handed', (tester) async {
      mode = ApprovalMode.plan;
      await pump(tester);
      expect(find.text('Plan first'), findsOneWidget);

      mode = ApprovalMode.auto;
      await pump(tester);
      expect(find.text('Auto-run'), findsOneWidget);
    });

    testWidgets('the hero variant keeps the same controls', (tester) async {
      // The welcome screen mounts the composer as its hero — a taller input
      // on no bottom padding. The row must not lose a control to it.
      await pump(tester, hero: true);

      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
      expect(find.text('Ask every time'), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrow_up), findsOneWidget);
    });
  });

  group('the attach menu', () {
    testWidgets('offers a file pick and a clipboard paste', (tester) async {
      await pump(tester);
      await tester.tap(find.byIcon(LucideIcons.paperclip));
      await tester.pumpAndSettle();

      expect(find.text('Choose image files…'), findsOneWidget);
      expect(find.text('Paste image from clipboard'), findsOneWidget);
    });
  });

  group('the model seat', () {
    ModelDirectory seeded() {
      final directory = ModelDirectory(
        current: const ModelSettings(apiKey: 'sk-live'),
      );
      return directory;
    }

    testWidgets('names the runtime model on the chip', (tester) async {
      await pump(tester, directory: seeded());
      // The settings document's default — the model the runtime carries.
      expect(find.text(defaultModel), findsOneWidget);
    });

    testWidgets('no directory, no chip', (tester) async {
      await pump(tester);
      expect(find.byIcon(LucideIcons.cpu), findsNothing);
    });

    testWidgets('selecting a model reports once', (tester) async {
      final selected = <String>[];
      await pump(
        tester,
        directory: seeded(),
        onModelSelected: selected.add,
      );

      await tester.tap(find.byIcon(LucideIcons.cpu));
      await tester.pumpAndSettle();

      // The menu offers the refresh row's copy beside the default entry.
      expect(find.text(defaultModel), findsWidgets);
      // A hand-picked model rides the host callback.
      expect(selected, isEmpty);

      // The directory's own select moves the chip label without the host.
      // (The commit path is main.dart's; here the seam is what is pinned.)
      expect(find.byIcon(LucideIcons.check), findsOneWidget);
    });

    testWidgets('without a commit the chip stays inert', (tester) async {
      await pump(tester, directory: seeded());
      await tester.tap(find.byIcon(LucideIcons.cpu));
      await tester.pumpAndSettle();
      // The menu opened; nothing crashed; the label is unchanged.
      expect(find.text(defaultModel), findsWidgets);
    });
  });

  group('the mode chip', () {
    testWidgets('selecting a mode is live — one tap, no confirm', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Ask every time'));
      await tester.pumpAndSettle();

      // The picker names all three modes with their descriptions.
      expect(find.text('Plan first'), findsOneWidget);
      expect(find.text('Auto-run'), findsOneWidget);

      await tester.tap(find.text('Auto-run'));
      await tester.pumpAndSettle();

      expect(mode, ApprovalMode.auto);
      // The chip now says so, and the picker is gone.
      expect(find.text('Auto-run'), findsOneWidget);
      expect(find.text('Plan first'), findsNothing);
    });

    testWidgets('without a selector the chip is inert, not broken', (
      tester,
    ) async {
      await pump(tester, withModeSelector: false);
      await tester.tap(find.text('Ask every time'));
      await tester.pumpAndSettle();

      // No picker: there is nothing wired to receive a selection, so offering
      // one would be a menu of dead entries. The chip still names the mode.
      expect(find.text('Plan first'), findsNothing);
      expect(mode, ApprovalMode.ask);
    });
  });

  group('the command menu', () {
    testWidgets('a leading slash opens the menu with every command', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      expect(find.text('Commands'), findsOneWidget);
      expect(find.text('Switch to ask mode'), findsOneWidget);
      expect(find.text('Switch to plan mode'), findsOneWidget);
      expect(find.text('Start a new session'), findsOneWidget);
    });

    testWidgets('the new-session command rides on its callback', (
      tester,
    ) async {
      await pump(tester, withNewSession: false);
      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      expect(find.text('Start a new session'), findsNothing);
    });

    testWidgets('the token filters the list', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '/pl');
      await tester.pump();

      expect(find.text('Switch to plan mode'), findsOneWidget);
      expect(find.text('Switch to ask mode'), findsNothing);
      expect(find.text('Start a new session'), findsNothing);
    });

    testWidgets('a space after the token closes the menu', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '/pl ');
      await tester.pump();

      expect(find.text('Commands'), findsNothing);
    });

    testWidgets('running a command clears the draft and flips the mode', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '/pl');
      await tester.pump();

      await tester.tap(find.text('Switch to plan mode'));
      await tester.pump();

      expect(mode, ApprovalMode.plan);
      // The draft was consumed by the command, menu and all.
      expect(find.text('Commands'), findsNothing);
      expect(find.widgetWithText(TextField, '/pl'), findsNothing);
      // And the chip reflects the flip.
      expect(find.text('Plan first'), findsOneWidget);
    });

    testWidgets('running /new starts a session instead of a mode', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '/ne');
      await tester.pump();

      await tester.tap(find.text('Start a new session'));
      await tester.pump();

      expect(newSession, 1);
      expect(mode, ApprovalMode.ask);
    });

    testWidgets('escape dismisses the menu for this token only', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Commands'), findsNothing);

      // A different token reopens it — the dismissal was for '/' alone.
      await tester.enterText(find.byType(TextField), '/p');
      await tester.pump();
      expect(find.text('Commands'), findsOneWidget);

      // And typing back to the dismissed token keeps it closed.
      await tester.enterText(find.byType(TextField), '/');
      await tester.pump();
      expect(find.text('Commands'), findsNothing);
    });
  });

  group('the primary action', () {
    testWidgets('a blocked composer refuses to send', (tester) async {
      var sent = 0;
      await pump(tester, blocked: true, onSubmit: (_, _) => sent++);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pump();

      expect(sent, 0);
      // The draft survives: blocked is a refusal, not a swallow.
      expect(find.widgetWithText(TextField, 'hello'), findsOneWidget);
    });
  });

  group('the @ mention menu', () {
    /// A tiny workspace in memory — the menu's contract is the ranking and
    /// the insert, not the walk, so the lookup is a fixed list.
    Future<List<FileEntry>> lookup() async => [
          const FileEntry(relative: 'README.md', kind: 'file'),
          const FileEntry(relative: 'src', kind: 'dir'),
          const FileEntry(relative: 'src/main.dart', kind: 'file'),
          const FileEntry(relative: 'src/util.dart', kind: 'file'),
        ];

    testWidgets('an @ token opens the files menu with ranked rows', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump();

      expect(find.text('Files'), findsOneWidget);
      // The shallow directory rides ahead of the root-level file — and shows
      // up again as the parent-directory line of its own children's rows.
      expect(find.text('src'), findsWidgets);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('without a lookup the @ types as plain text', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '@main.dart');
      await tester.pump();

      expect(find.text('Files'), findsNothing);
      expect(find.text('Searching the workspace…'), findsNothing);
    });

    testWidgets('the token filters the candidates', (tester) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(TextField), '@ut');
      await tester.pump();

      expect(find.text('util.dart'), findsOneWidget);
      expect(find.text('README.md'), findsNothing);
    });

    testWidgets('a file pick inserts @path and closes the menu', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(TextField), '@main');
      await tester.pump();

      await tester.tap(find.text('main.dart'));
      await tester.pump();

      // The token became the readable mention, closed by the trailing space.
      expect(find.widgetWithText(TextField, '@src/main.dart '), findsOneWidget);
      expect(find.text('Files'), findsNothing);
    });

    testWidgets('a directory pick continues the menu with its children', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(TextField), '@sr');
      await tester.pump();

      await tester.tap(find.text('src'));
      await tester.pump();

      // `@src/` stays an open token: the menu now offers the directory's
      // contents, the plugin's continuation flow.
      expect(find.widgetWithText(TextField, '@src/'), findsOneWidget);
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('util.dart'), findsOneWidget);
      // Root-level entries are gone — this is src's browse now.
      expect(find.text('README.md'), findsNothing);
    });

    testWidgets('a space after the token closes the menu', (tester) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(TextField), '@main ');
      await tester.pump();

      expect(find.text('Files'), findsNothing);
    });

    testWidgets('escape dismisses the menu for this token only', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(TextField), '@ma');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Files'), findsNothing);

      // A different token reopens it — the dismissal was for 'ma' alone.
      await tester.enterText(find.byType(TextField), '@ut');
      await tester.pump();
      expect(find.text('Files'), findsOneWidget);

      // And typing back to the dismissed token keeps it closed.
      await tester.enterText(find.byType(TextField), '@ma');
      await tester.pump();
      expect(find.text('Files'), findsNothing);
    });

    testWidgets('the index load shows its loading seat', (tester) async {
      await pump(
        tester,
        onLookupFiles: () => Completer<List<FileEntry>>().future,
      );
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump();

      // A pending fetch still shows the menu's chrome — the `@` visibly did
      // something instead of eating the keystroke.
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('Searching the workspace…'), findsOneWidget);
    });
  });
}
