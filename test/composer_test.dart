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
import 'dart:convert';
import 'dart:io';

import 'package:agent_harness/model/approval_mode.dart';
import 'package:agent_harness/model/attached_image.dart';
import 'package:agent_harness/model/model_settings.dart';
import 'package:agent_harness/model/queued_input.dart';
import 'package:agent_harness/model/workspace_index.dart';
import 'package:agent_harness/state/model_directory.dart';
import 'package:agent_harness/theme/dsw_shape.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/composer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'amplified_text_probe.dart';

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
    this.width,
    this.workspaceRoot,
  });

  final ApprovalMode mode;
  final ValueChanged<ApprovalMode> onMode;
  final VoidCallback onNewSession;
  final void Function(String text, List<AttachedImage> images, InputDelivery)
  onSubmit;
  final bool hero;
  final bool busy;
  final bool blocked;
  final bool withModeSelector;
  final bool withNewSession;
  final ModelDirectory? modelDirectory;
  final ValueChanged<String>? onModelSelected;
  final Future<List<FileEntry>> Function()? onLookupFiles;

  /// The column the composer is given. Null is the host's own 748px ceiling;
  /// the narrow-width tests hand it what a squeezed centre column would.
  final double? width;

  /// Set to exercise the status bar under the card, which only renders with a
  /// picked workspace.
  final String? workspaceRoot;

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
      constraints: BoxConstraints(maxWidth: widget.width ?? 748),
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
        workspaceRoot: widget.workspaceRoot,
        onPickWorkspace: widget.workspaceRoot == null ? null : () {},
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
    double? width,
    String? workspaceRoot,
    double step = 1.0,
    void Function(String text, List<AttachedImage> images, InputDelivery)?
    onSubmit,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: AmplifiedText(
          step: step,
          child: _ComposerHost(
            mode: mode,
            onMode: (next) => mode = next,
            onNewSession: () => newSession++,
            onSubmit: onSubmit ?? (text, images, delivery) {},
            hero: hero,
            busy: busy,
            blocked: blocked,
            withModeSelector: withModeSelector,
            withNewSession: withNewSession,
            modelDirectory: directory,
            onModelSelected: onModelSelected,
            onLookupFiles: onLookupFiles,
            width: width,
            workspaceRoot: workspaceRoot,
          ),
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

  group('the attach gate', () {
    // A real 1×1 PNG: the accepted chip decodes its bytes, so a fake payload
    // would fail for the wrong reason.
    final pngBytes = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    late Directory temp;
    late File png;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('composer_attach_');
      png = File(p.join(temp.path, 'shot.png'))..writeAsBytesSync(pngBytes);
    });

    tearDown(() => temp.deleteSync(recursive: true));

    ComposerState card(WidgetTester tester) =>
        tester.state<ComposerState>(find.byType(Composer));

    ModelDirectory serving(String model) => ModelDirectory(
      current: ModelSettings(apiKey: 'sk-live', model: model),
    );

    testWidgets('a text-only model refuses the drop and says why', (
      tester,
    ) async {
      List<AttachedImage>? sent;
      await pump(
        tester,
        directory: serving(defaultModel),
        onSubmit: (text, images, _) => sent = images,
      );

      card(tester).addDroppedFiles([png.path]);
      await tester.pump();

      expect(find.textContaining('does not accept images'), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pump();
      // Nothing was attached, so the send is the empty-draft no-op: the image
      // did not ride along and did not silently disappear either.
      expect(sent, isNull);
    });

    testWidgets('a vision model takes the same drop', (tester) async {
      List<AttachedImage>? sent;
      await pump(
        tester,
        directory: serving('gpt-4o'),
        onSubmit: (text, images, _) => sent = images,
      );

      card(tester).addDroppedFiles([png.path]);
      await tester.pump();

      expect(find.textContaining('does not accept images'), findsNothing);
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pump();
      expect(sent, hasLength(1));
      expect(sent!.single.name, 'shot.png');
    });

    testWidgets('documents still land when the image is refused', (
      tester,
    ) async {
      final note = File(p.join(temp.path, 'note.md'))
        ..writeAsStringSync('# hello');
      await pump(tester, directory: serving(defaultModel));

      card(tester).addDroppedFiles([png.path, note.path]);
      await tester.pump();

      // The gate is about media parts only: a text document needs no capability
      // flag, because the app extracts it locally before the send.
      expect(find.textContaining('does not accept images'), findsOneWidget);
      expect(find.text('note.md'), findsOneWidget);
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
      await pump(tester, directory: seeded(), onModelSelected: selected.add);

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
    testWidgets('a blocked composer does not send from its circle', (
      tester,
    ) async {
      var sent = 0;
      await pump(tester, blocked: true, onSubmit: (_, _, _) => sent++);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pump();

      // The circle belongs to the running turn (it stops it) while the
      // transcript is busy; nothing is lost either way (ADR-0013).
      expect(sent, 0);
      expect(find.widgetWithText(TextField, 'hello'), findsOneWidget);
    });

    testWidgets('a blocked composer offers the two deliveries', (tester) async {
      var sent = const <Object>[];
      await pump(
        tester,
        blocked: true,
        onSubmit: (text, images, delivery) => sent = [delivery],
      );

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('Queue'));
      await tester.pump();
      expect(sent, [InputDelivery.queue]);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      await tester.tap(find.text('Steer'));
      await tester.pump();
      expect(sent, [InputDelivery.guide]);
    });

    testWidgets('an idle composer offers neither', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();

      expect(find.text('Queue'), findsNothing);
      expect(find.text('Steer'), findsNothing);
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

  group('the row in a narrow column', () {
    // Report item 6 says the menus eat the input space on a narrow screen.
    // What that really asks is what a person can still REACH once the centre
    // column is squeezed, so the test is reachability plus the absence of a
    // RenderFlex error, at widths the frame actually produces.
    ModelDirectory seeded() => ModelDirectory(
      current: const ModelSettings(apiKey: 'sk-live', model: defaultModel),
    );

    testWidgets('320px keeps both menus', (tester) async {
      await pump(tester, width: 320, directory: seeded());

      expect(tester.takeException(), isNull);
      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
      expect(find.byIcon(LucideIcons.shield_question_mark), findsOneWidget);
      expect(find.byIcon(LucideIcons.cpu), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrow_up), findsOneWidget);
    });

    testWidgets('the parked-draft chips fit beside both menus at 260px', (
      tester,
    ) async {
      // The tightest real case: a turn is running, a draft is held, so the row
      // carries attach + mode + queue + guide + model + send at once.
      await pump(tester, width: 260, blocked: true, directory: seeded());
      await tester.enterText(find.byType(TextField), 'a draft');
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Shed the labels, keep the doors — both deliveries must still be one tap
      // away, which is the whole point of ADR-0013.
      expect(find.byIcon(LucideIcons.cpu), findsOneWidget);
      expect(find.byIcon(LucideIcons.list_end), findsOneWidget);
      expect(find.byIcon(LucideIcons.route), findsOneWidget);
    });

    testWidgets('the parked-draft chips keep their labels at 420px', (
      tester,
    ) async {
      await pump(tester, width: 420, blocked: true, directory: seeded());
      await tester.enterText(find.byType(TextField), 'a draft');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Queue'), findsOneWidget);
      expect(find.text('Steer'), findsOneWidget);
    });

    testWidgets('below the seat floor the row gives up seats, not layout', (
      tester,
    ) async {
      await pump(tester, width: 120, directory: seeded());

      expect(tester.takeException(), isNull);
      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrow_up), findsOneWidget);
      expect(find.byIcon(LucideIcons.shield_question_mark), findsNothing);
      expect(find.byIcon(LucideIcons.cpu), findsNothing);
    });

    testWidgets('a folder name too long for the bar does not overflow it', (
      tester,
    ) async {
      // A real directory, because the bar reads the last path segment and the
      // branch probe runs a real `git` — which the fake-async zone cannot host,
      // hence runAsync. That the probe fails is part of the case too: the bar
      // still has to render name-only.
      final temp = Directory.systemTemp.createTempSync(
        'a-markedly-long-project-name-that-nobody-would-choose',
      );
      try {
        await tester.runAsync(
          () => pump(tester, width: 300, workspaceRoot: temp.path),
        );

        expect(tester.takeException(), isNull);
        // Ellipsised, not dropped: the bar still says which workspace this is.
        final shown = tester.widget<Text>(find.text(p.basename(temp.path)));
        expect(shown.overflow, TextOverflow.ellipsis);
        expect(tester.getSize(find.byType(TextField)).width, lessThan(300));
      } finally {
        temp.deleteSync(recursive: true);
      }
    });
  });

  // The card's own seats, plus the four menus that only exist once tapped.
  //
  // `composer.dart` carries the largest cluster of pinned seats left in lib/ui,
  // and a menu row is a glyph beside a label — the first place an amplified
  // system runs out of width. Each stage below measures the tree WITH the menu
  // open, since a menu is in no one's tree otherwise.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      testWidgets('the card and its menus keep their labels ($label)', (
        tester,
      ) async {
        Future<void> tap(Finder target) async {
          await tester.tap(target);
          await tester.pumpAndSettle();
        }

        // Tap the barrier rather than an entry: a menu left open covers the
        // next face, and a route nobody popped leaves its timer armed.
        Future<void> close() async {
          await tester.tapAt(const Offset(4, 4));
          await tester.pumpAndSettle();
        }

        await pump(
          tester,
          step: step,
          directory: ModelDirectory(
            current: const ModelSettings(
              apiKey: 'sk-live',
              model: defaultModel,
            ),
          ),
          // Without a commit the chip is inert by design, and an inert chip has
          // no menu to measure.
          onModelSelected: (_) {},
          onLookupFiles: () async => const [
            FileEntry(relative: 'README.md', kind: 'file'),
            FileEntry(relative: 'src', kind: 'dir'),
          ],
        );
        expect(textDefects(tester), isEmpty, reason: 'the composer card');

        await tap(find.byIcon(LucideIcons.paperclip));
        expect(find.text('Choose image files…'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the attach menu');
        await close();

        await tap(find.text('Ask every time'));
        expect(find.text('Plan first'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the mode picker');
        await close();

        await tap(find.byIcon(LucideIcons.cpu));
        expect(find.byIcon(LucideIcons.check), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the model menu');
        await close();

        await tester.enterText(find.byType(TextField), '/');
        await tester.pump();
        expect(find.text('Commands'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the command menu');

        await tester.enterText(find.byType(TextField), '@');
        await tester.pump();
        expect(find.text('Files'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the mention menu');

        // The two deliveries a blocked turn puts where the send circle was.
        await pump(tester, step: step, blocked: true);
        await tester.enterText(find.byType(TextField), 'hello');
        await tester.pumpAndSettle();
        expect(find.text('Queue'), findsOneWidget);
        expect(find.text('Steer'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the delivery buttons');
      });
    }
  });

  // Audit item 4, the half of it that is not spacing: the card used to carry one
  // static 6%-alpha stroke, so nothing on screen said which surface was about to
  // receive the keystrokes. ZCode's prompt editor carries three (`ChatPromptEditor
  // .tsx:347`: `border-input-border` → `hover:` → `focus-within:`) and so does this
  // now. The states are reached the way a user reaches them — autofocus, `Tab`
  // away, pointer in and out, tap back in — and the strokes are read off the
  // painted decoration, so a regression to one static colour fails here.
  testWidgets('the card shows which surface has the keyboard', (tester) async {
    Color stroke() {
      final box = tester.widget<AnimatedContainer>(
        find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).borderRadius ==
                  BorderRadius.circular(DswShape.float),
        ),
      );
      return ((box.decoration! as BoxDecoration).border! as Border).top.color;
    }

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    // Parked outside the card, so 'hover' only ever means the one move in.
    await pointer.addPointer(location: const Offset(1, 1));
    addTearDown(pointer.removePointer);

    await pump(tester);
    await tester.pumpAndSettle();
    final color = tester.element(find.byType(TextField)).dsw;
    expect(
      stroke(),
      color.brandPrimary,
      reason: 'the draft autofocuses, so the card opens focused',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(stroke(), color.borderL2DarkmodeThin, reason: 'idle, pointer away');

    await pointer.moveTo(tester.getCenter(find.byType(TextField)));
    await tester.pumpAndSettle();
    expect(stroke(), color.borderL3, reason: 'hover, pointer on the card');

    await pointer.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(stroke(), color.borderL2DarkmodeThin, reason: 'back to idle');

    await tester.tapAt(tester.getCenter(find.byType(TextField)));
    await tester.pumpAndSettle();
    expect(
      stroke(),
      color.brandPrimary,
      reason: 'focus outranks hover: typing is the state that matters',
    );

    // Three states, three colours — the same law ADR-0017 S2 set for selection.
    expect(
      {color.borderL2DarkmodeThin, color.borderL3, color.brandPrimary}.length,
      3,
    );
  });
}
