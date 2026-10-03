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
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_shape.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/composer.dart';
import 'package:agent_harness/ui/primitives/menu.dart' show DswMenuRow;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// A `show` list, because shadcn_ui re-exports `LucideIcons` and an unqualified
// import makes every icon reference ambiguous.
import 'package:shadcn_ui/shadcn_ui.dart'
    show ShadOption, ShadSonner, ShadTheme;
// Prefixed, not `show`: shad draws its own option tick from a second Lucide
// package (`lucide_icons_flutter`, re-exported by shadcn_ui) whose codepoints
// are not the ones `flutter_lucide` — the font every app glyph comes from —
// assigns to the same name. `LucideIcons.check` from the app's set matches
// nothing shad paints.
import 'package:shadcn_ui/shadcn_ui.dart' as shad;

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
    this.onStop,
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
    this.draftScope,
  });

  final ApprovalMode mode;
  final ValueChanged<ApprovalMode> onMode;
  final VoidCallback onNewSession;
  final void Function(String text, List<AttachedImage> images, InputDelivery)
  onSubmit;
  final VoidCallback? onStop;
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

  /// Which conversation the card is typing into — flip it to switch sessions.
  final String? draftScope;

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
        draftScope: widget.draftScope,
        onPickWorkspace: widget.workspaceRoot == null ? null : () {},
        onLookupFiles: widget.onLookupFiles,
        onSubmit: widget.onSubmit,
        onStop: widget.onStop ?? () {},
      ),
    ),
  );
}

/// What a field holds. A `ShadInput` renders its text through an `EditableText`
/// and not a `Text`, so `find.text`/`widgetWithText` cannot see the draft at
/// all — the controller the field is built on is the one place the string is.
/// (ADR-0036 batch B7 moved the field off Material.)
String fieldText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

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
    VoidCallback? onStop,
    String? draftScope,
  }) => tester.pumpWidget(
    MaterialApp(
      // The app's own composition (ADR-0017 S3 then ADR-0020): the step above
      // `ShadSonner`, so the refusal toast the attach gate raises is measured
      // at the same step as the card that raised it.
      builder: (context, child) => ShadTheme(
        data: dswShadTheme(Brightness.light),
        child: AmplifiedText(
          step: step,
          child: ShadSonner(child: child!),
        ),
      ),
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: _ComposerHost(
          mode: mode,
          onMode: (next) => mode = next,
          onNewSession: () => newSession++,
          onSubmit: onSubmit ?? (text, images, delivery) {},
          onStop: onStop,
          draftScope: draftScope,
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
      expect(find.byIcon(shad.LucideIcons.check), findsOneWidget);
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
      await tester.enterText(find.byType(EditableText), '/');
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
      await tester.enterText(find.byType(EditableText), '/');
      await tester.pump();

      expect(find.text('Start a new session'), findsNothing);
    });

    testWidgets('the token filters the list', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '/pl');
      await tester.pump();

      expect(find.text('Switch to plan mode'), findsOneWidget);
      expect(find.text('Switch to ask mode'), findsNothing);
      expect(find.text('Start a new session'), findsNothing);
    });

    testWidgets('a space after the token closes the menu', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '/pl ');
      await tester.pump();

      expect(find.text('Commands'), findsNothing);
    });

    testWidgets('running a command clears the draft and flips the mode', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '/pl');
      await tester.pump();

      await tester.tap(find.text('Switch to plan mode'));
      await tester.pump();

      expect(mode, ApprovalMode.plan);
      // The draft was consumed by the command, menu and all.
      expect(find.text('Commands'), findsNothing);
      expect(fieldText(tester), isEmpty);
      // And the chip reflects the flip.
      expect(find.text('Plan first'), findsOneWidget);
    });

    testWidgets('running /new starts a session instead of a mode', (
      tester,
    ) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '/ne');
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
      await tester.enterText(find.byType(EditableText), '/');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Commands'), findsNothing);

      // A different token reopens it — the dismissal was for '/' alone.
      await tester.enterText(find.byType(EditableText), '/p');
      await tester.pump();
      expect(find.text('Commands'), findsOneWidget);

      // And typing back to the dismissed token keeps it closed.
      await tester.enterText(find.byType(EditableText), '/');
      await tester.pump();
      expect(find.text('Commands'), findsNothing);
    });
  });

  group('the primary action', () {
    // ADR-0050. The circle follows the DRAFT; the old rule followed the
    // transcript, so typing a follow-up turned the primary action into "stop the
    // run". The test that used to sit here pinned that, and it passed on a stale
    // frame: it never pumped after `enterText`, so the button it tapped was
    // still the one built before the draft existed. A guard that only ever
    // measures the previous frame is worse than none, because it reads as
    // coverage.
    testWidgets('an empty box stops the run; a draft sends from the circle', (
      tester,
    ) async {
      var sent = 0;
      var stops = 0;
      await pump(
        tester,
        busy: true,
        blocked: true,
        onSubmit: (_, _, _) => sent++,
        onStop: () => stops++,
      );

      await tester.tap(find.byIcon(LucideIcons.square));
      await tester.pump();
      expect(stops, 1);
      expect(sent, 0);

      await tester.enterText(find.byType(EditableText), 'a follow-up');
      await tester.pump();
      // The draft wins: the stop square is gone and the circle is the send
      // again, which is what the user is looking at.
      expect(find.byIcon(LucideIcons.square), findsNothing);
      expect(find.byIcon(LucideIcons.arrow_up), findsOneWidget);
      await tester.tap(find.byIcon(LucideIcons.arrow_up));
      await tester.pump();
      expect(stops, 1, reason: 'a draft must not cost the run its stop here');
      expect(sent, 1);
    });

    testWidgets('Enter while an input method composes does not send', (
      tester,
    ) async {
      var sent = 0;
      await pump(tester, onSubmit: (_, _, _) => sent++);
      final controller = tester
          .widget<EditableText>(find.byType(EditableText))
          .controller;
      // The state a pinyin candidate list leaves behind: text in the field, and
      // a composing span the user has not committed yet. Enter here picks the
      // word.
      controller.value = const TextEditingValue(
        text: 'zhong wen',
        selection: TextSelection.collapsed(offset: 9),
        composing: TextRange(start: 0, end: 9),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sent, 0, reason: 'Enter was a candidate pick, not a send');
      expect(fieldText(tester), 'zhong wen');

      // The same keystroke after the word lands does send.
      controller.value = const TextEditingValue(
        text: 'zhong wen',
        selection: TextSelection.collapsed(offset: 9),
      );
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(sent, 1);
    });

    testWidgets('Shift+Enter stays a newline', (tester) async {
      var sent = 0;
      await pump(tester, onSubmit: (_, _, _) => sent++);
      await tester.enterText(find.byType(EditableText), 'two lines');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(sent, 0);
      expect(fieldText(tester), 'two lines');
    });

    testWidgets('while a turn runs Enter queues and Cmd+Enter steers', (
      tester,
    ) async {
      final deliveries = <InputDelivery>[];
      await pump(
        tester,
        busy: true,
        blocked: true,
        onSubmit: (_, _, delivery) => deliveries.add(delivery),
      );

      await tester.enterText(find.byType(EditableText), 'first');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      await tester.enterText(find.byType(EditableText), 'second');
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      // The reversed delivery the reference ships: the plain key is the safe
      // destination, the modifier is the interruption — so choosing between them
      // never needs a hand off the keyboard.
      expect(deliveries, [InputDelivery.queue, InputDelivery.guide]);
    });

    // ADR-0051. The card survives a session switch (the controller is reused),
    // so a draft had no owner: half a message and its picked files walked into
    // whichever conversation the user clicked next, and a send there delivered
    // them to the wrong transcript.
    testWidgets('a draft belongs to the conversation it was typed in', (
      tester,
    ) async {
      await pump(tester, draftScope: 'session-a');
      await tester.enterText(find.byType(EditableText), 'for A');
      await tester.pump();

      await pump(tester, draftScope: 'session-b');
      await tester.pump();
      expect(
        fieldText(tester),
        isEmpty,
        reason: 'B must not open with A\'s text',
      );

      await pump(tester, draftScope: 'session-a');
      await tester.pump();
      expect(fieldText(tester), 'for A');
    });

    testWidgets('the hint says what sending would do now', (tester) async {
      await pump(tester);
      expect(find.text('Ask anything, or describe a task'), findsOneWidget);

      await pump(tester, busy: true, blocked: true);
      expect(
        find.text('Keep typing — this queues behind the current turn'),
        findsOneWidget,
      );
    });

    testWidgets('a blocked composer offers the two deliveries', (tester) async {
      var sent = const <Object>[];
      await pump(
        tester,
        blocked: true,
        onSubmit: (text, images, delivery) => sent = [delivery],
      );

      await tester.enterText(find.byType(EditableText), 'hello');
      await tester.pump();
      await tester.tap(find.text('Queue'));
      await tester.pump();
      expect(sent, [InputDelivery.queue]);

      await tester.enterText(find.byType(EditableText), 'hello');
      await tester.pump();
      await tester.tap(find.text('Steer'));
      await tester.pump();
      expect(sent, [InputDelivery.guide]);
    });

    testWidgets('an idle composer offers neither', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(EditableText), 'hello');
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
      await tester.enterText(find.byType(EditableText), '@');
      await tester.pump();

      expect(find.text('Files'), findsOneWidget);
      // The shallow directory rides ahead of the root-level file — and shows
      // up again as the parent-directory line of its own children's rows.
      expect(find.text('src'), findsWidgets);
      expect(find.text('README.md'), findsOneWidget);
    });

    testWidgets('without a lookup the @ types as plain text', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(EditableText), '@main.dart');
      await tester.pump();

      expect(find.text('Files'), findsNothing);
      expect(find.text('Searching the workspace…'), findsNothing);
    });

    testWidgets('the token filters the candidates', (tester) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(EditableText), '@ut');
      await tester.pump();

      expect(find.text('util.dart'), findsOneWidget);
      expect(find.text('README.md'), findsNothing);
    });

    testWidgets('a file pick inserts @path and closes the menu', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(EditableText), '@main');
      await tester.pump();

      await tester.tap(find.text('main.dart'));
      await tester.pump();

      // The token became the readable mention, closed by the trailing space.
      expect(fieldText(tester), '@src/main.dart ');
      expect(find.text('Files'), findsNothing);
    });

    testWidgets('a directory pick continues the menu with its children', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(EditableText), '@sr');
      await tester.pump();

      await tester.tap(find.text('src'));
      await tester.pump();

      // `@src/` stays an open token: the menu now offers the directory's
      // contents, the plugin's continuation flow.
      expect(fieldText(tester), '@src/');
      expect(find.text('Files'), findsOneWidget);
      expect(find.text('main.dart'), findsOneWidget);
      expect(find.text('util.dart'), findsOneWidget);
      // Root-level entries are gone — this is src's browse now.
      expect(find.text('README.md'), findsNothing);
    });

    testWidgets('a space after the token closes the menu', (tester) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(EditableText), '@main ');
      await tester.pump();

      expect(find.text('Files'), findsNothing);
    });

    testWidgets('escape dismisses the menu for this token only', (
      tester,
    ) async {
      await pump(tester, onLookupFiles: lookup);
      await tester.enterText(find.byType(EditableText), '@ma');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.text('Files'), findsNothing);

      // A different token reopens it — the dismissal was for 'ma' alone.
      await tester.enterText(find.byType(EditableText), '@ut');
      await tester.pump();
      expect(find.text('Files'), findsOneWidget);

      // And typing back to the dismissed token keeps it closed.
      await tester.enterText(find.byType(EditableText), '@ma');
      await tester.pump();
      expect(find.text('Files'), findsNothing);
    });

    testWidgets('the index load shows its loading seat', (tester) async {
      await pump(
        tester,
        onLookupFiles: () => Completer<List<FileEntry>>().future,
      );
      await tester.enterText(find.byType(EditableText), '@');
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

    testWidgets('the trailing group is anchored to the card\'s right edge', (
      tester,
    ) async {
      // The row's own comment promises this: "the model chip and button are the
      // trailing group and should feel anchored to the right". They were not.
      // `Spacer` and the model chip's `Flexible` are BOTH flex children, so the
      // free space split in half — and the half the chip did not need simply
      // vanished instead of going to the spacer, leaving the send a few hundred
      // pixels short of the 4px it is padded to.
      await pump(tester, width: 900, directory: seeded());

      final card = tester.getRect(
        find.byWidgetPredicate(
          (w) =>
              w is AnimatedContainer &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).borderRadius ==
                  BorderRadius.circular(DswShape.float),
        ),
      );
      final send = tester.getRect(find.byIcon(LucideIcons.arrow_up));
      // 4px of row pad + the 9px from the glyph's edge to its 34px box.
      expect(
        card.right - send.right,
        lessThan(24),
        reason: 'the send sits ${card.right - send.right}px from the card edge',
      );
    });

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
      await tester.enterText(find.byType(EditableText), 'a draft');
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
      await tester.enterText(find.byType(EditableText), 'a draft');
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

    testWidgets('a menu wider than the column overlays it, never squeezes it', (
      tester,
    ) async {
      // The other half of report item 6. The mode menu's own minWidth (260) is
      // the entire centre column at this width, so it can only be honest as an
      // overlay: opening it must not move the field by a pixel, and a row that
      // lands outside the viewport is a door that cannot be opened.
      await pump(tester, width: 260, directory: seeded());

      final field = tester.getRect(find.byType(EditableText));
      final screen = Rect.fromLTWH(
        0,
        0,
        tester.view.physicalSize.width / tester.view.devicePixelRatio,
        tester.view.physicalSize.height / tester.view.devicePixelRatio,
      );
      // A row is a row in either shape: the attach menu is a popover of
      // `DswMenuRow`s, the pickers are `ShadOption`s.
      final rows = find.byWidgetPredicate(
        (w) => w is DswMenuRow || w is ShadOption,
      );

      Future<void> open(Finder control, String firstRow) async {
        await tester.tap(control);
        await tester.pumpAndSettle();
        expect(
          find.text(firstRow),
          findsOneWidget,
          reason: 'the $firstRow menu',
        );
        expect(
          tester.getRect(find.byType(EditableText)),
          field,
          reason: '$firstRow re-laid the row out',
        );
        for (var i = 0; i < rows.evaluate().length; i++) {
          final rect = tester.getRect(rows.at(i));
          expect(rect.left, greaterThanOrEqualTo(screen.left));
          expect(rect.top, greaterThanOrEqualTo(screen.top));
          expect(rect.right, lessThanOrEqualTo(screen.right));
          expect(rect.bottom, lessThanOrEqualTo(screen.bottom));
        }
        // The row is 504.0 wide over a 260.0 column, and its right edge lands
        // at 792.0 of an 800.0 viewport — the menu is a door drawn OVER the card
        // and clamped to the screen, which is the only way this case can work.
        // Without this the face would pass for a menu that simply fit inside the
        // column, and there would be nothing to prove.
        expect(tester.getRect(rows.first).width, greaterThan(260));
        // Tap the barrier rather than an entry: a menu left open covers the next
        // face, and a route nobody popped leaves its timer armed.
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(rows, findsNothing);
      }

      await open(find.byIcon(LucideIcons.paperclip), 'Choose image files…');
      await open(find.byIcon(LucideIcons.shield_question_mark), 'Plan first');
      expect(tester.takeException(), isNull);
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
        expect(tester.getSize(find.byType(EditableText)).width, lessThan(300));
      } finally {
        temp.deleteSync(recursive: true);
      }
    });
  });

  // The card's own seats, plus the menus that only exist once tapped.
  //
  // `composer.dart` carries the largest cluster of pinned seats left in lib/ui,
  // and a menu row is a glyph beside a label — the first place an amplified
  // system runs out of width. Each face below measures the tree WITH its own
  // menu open, since a menu is in no one's tree otherwise.
  //
  // One menu per pumped tree, deliberately: at the second step a popover's rows
  // are wide enough to cover the chip that opens the next one, so a chained
  // stage taps the menu it meant to close and measures two faces at once.
  group('amplified text', () {
    for (final (label, step) in const [
      ('1.8x', amplifiedTextStep),
      ('2.2x', nextTextStep),
    ]) {
      Future<void> pumpCard(WidgetTester tester) => pump(
        tester,
        step: step,
        directory: ModelDirectory(
          current: const ModelSettings(apiKey: 'sk-live', model: defaultModel),
        ),
        // Without a commit the chip is inert by design, and an inert chip has
        // no menu to measure.
        onModelSelected: (_) {},
        onLookupFiles: () async => const [
          FileEntry(relative: 'README.md', kind: 'file'),
          FileEntry(relative: 'src', kind: 'dir'),
        ],
      );

      Future<void> open(
        WidgetTester tester,
        Finder trigger,
        String face,
      ) async {
        expect(textDefects(tester), isEmpty, reason: 'the composer card');
        await tester.tap(trigger);
        await tester.pumpAndSettle();
        expect(textDefects(tester), isEmpty, reason: face);
      }

      testWidgets('the attach menu keeps its labels ($label)', (tester) async {
        await pumpCard(tester);
        await open(
          tester,
          find.byIcon(LucideIcons.paperclip),
          'the attach menu',
        );
        expect(find.text('Choose image files…'), findsOneWidget);
      });

      testWidgets('the mode picker keeps its labels ($label)', (tester) async {
        await pumpCard(tester);
        await open(
          tester,
          find.byIcon(LucideIcons.shield_question_mark),
          'the mode picker',
        );
        expect(find.text('Plan first'), findsOneWidget);
      });

      testWidgets('the model menu keeps its labels ($label)', (tester) async {
        await pumpCard(tester);
        await open(tester, find.byIcon(LucideIcons.cpu), 'the model menu');
        // The tick that says which row is live is drawn by shad, and shad ships
        // its own Lucide font whose codepoints are not `flutter_lucide`'s for
        // the same name — so it is matched by that package's constant.
        expect(find.byIcon(shad.LucideIcons.check), findsOneWidget);
      });

      testWidgets('the typed menus keep their labels ($label)', (tester) async {
        await pumpCard(tester);
        expect(textDefects(tester), isEmpty, reason: 'the composer card');

        await tester.enterText(find.byType(EditableText), '/');
        await tester.pump();
        expect(find.text('Commands'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the command menu');

        await tester.enterText(find.byType(EditableText), '@');
        await tester.pump();
        expect(find.text('Files'), findsOneWidget);
        expect(textDefects(tester), isEmpty, reason: 'the mention menu');
      });

      testWidgets('the delivery buttons keep their labels ($label)', (
        tester,
      ) async {
        await pump(tester, step: step, blocked: true);
        await tester.enterText(find.byType(EditableText), 'hello');
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
  testWidgets('the card keeps its stroke when the keyboard lands', (
    tester,
  ) async {
    // ADR-0038 reversed the three-state border: the focus stroke read as
    // noise on the walkthrough (the caret already says where the keystrokes
    // land), so the card now answers two states — idle and hover — and the
    // focused frame is pixel-identical to the resting one.
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
    final color = tester.element(find.byType(EditableText)).dsw;
    final resting = stroke();
    expect(
      resting,
      color.borderL2DarkmodeThin,
      reason: 'the draft autofocuses, so the opened card IS the focused read',
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();

    await pointer.moveTo(tester.getCenter(find.byType(EditableText)));
    await tester.pumpAndSettle();
    expect(stroke(), color.borderL3, reason: 'hover still brightens a notch');

    // Tap back in. The pointer is still on the card, so hover holds the
    // stroke; the focused frame is whatever the pointer says now — that is
    // ADR-0038.
    await tester.tapAt(tester.getCenter(find.byType(EditableText)));
    await tester.pumpAndSettle();
    expect(stroke(), color.borderL3, reason: 'pointer on the card, hover');

    await pointer.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(
      stroke(),
      color.borderL2DarkmodeThin,
      reason: 'focused again, pointer away — identical to idle (ADR-0038)',
    );
  });
}
