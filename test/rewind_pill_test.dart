// The pill, the promise, and the two things that must not happen: an undo
// offered where there is nothing to undo, and an undo run without asking
// (ADR-0014 S3).
//
// Rendered as a real card, because what is being tested is the card's own
// decision — which tool outputs earn a pill, what the confirmation says, and
// whether the report afterwards matches the preview before it. The store behind
// it is a pair of closures: their behaviour is `checkpoint_test.dart`'s job.

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/state/checkpoint_store.dart';
import 'package:agent_harness/theme/dsw_shad_bridge.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/appearance_scope.dart';
import 'package:agent_harness/ui/conversation/conversation_root.dart';
import 'package:agent_harness/ui/tool/checkpoint_scope.dart';
import 'package:agent_harness/ui/tool/tool_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  final previews = <String>[];
  final rewinds = <String>[];
  List<RewindFile> nextPreview = const [];
  RewindReport nextReport = RewindReport.empty;

  setUp(() {
    previews.clear();
    rewinds.clear();
    nextPreview = const [];
    nextReport = RewindReport.empty;
  });

  /// A write card, expanded by the appearance preference the app itself mounts,
  /// over a rewind service that records what the card asked for.
  Future<void> pumpCard(
    WidgetTester tester, {
    required String tool,
    Map<String, dynamic>? output,
    bool withScope = true,
  }) {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final card = ToolCard(
      node: ToolCallNode(
        id: 'call-1',
        name: tool,
        arguments: const {'file_path': 'a.dart', 'content': 'written'},
        status: ToolStatus.succeeded,
        output: output,
      ),
    );
    return tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        // Mirrors main's MaterialApp.builder: the confirmation is a ShadDialog,
        // and the report the rewind ends with is a Sonner toast (ADR-0020), so
        // both hosts are mounted the way the app mounts them.
        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: ShadSonner(child: child!),
        ),
        home: Scaffold(
          body: AppearanceScope(
            contentWidth: chatContentWidth,
            expandToolCalls: true,
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 640,
                child: withScope
                    ? CheckpointScope(
                        preview: (id) {
                          previews.add(id);
                          return nextPreview;
                        },
                        rewind: (id) {
                          rewinds.add(id);
                          return nextReport;
                        },
                        child: card,
                      )
                    : card,
              ),
            ),
          ),
        ),
      ),
    );
  }

  const written = {'ok': true, 'path': 'a.dart', 'checkpoint': 'c1'};

  Future<void> openConfirmation(WidgetTester tester) async {
    await tester.tap(find.text('Undo this write'));
    await tester.pumpAndSettle();
  }

  group('who earns the pill', () {
    testWidgets('a write that named its checkpoint', (tester) async {
      await pumpCard(tester, tool: 'write', output: written);
      expect(find.text('Undo this write'), findsOneWidget);
    });

    testWidgets('an edit too', (tester) async {
      await pumpCard(tester, tool: 'edit', output: written);
      expect(find.text('Undo this write'), findsOneWidget);
    });

    testWidgets('not a write that recorded nothing', (tester) async {
      await pumpCard(tester, tool: 'write', output: const {'ok': true});
      expect(find.text('Undo this write'), findsNothing);
    });

    testWidgets('not any other tool, even one whose output carries the key', (
      tester,
    ) async {
      // An MCP server returning a `checkpoint` string would otherwise buy a pill
      // that points at a record no store has ever seen.
      await pumpCard(tester, tool: 'bash', output: written);
      expect(find.text('Undo this write'), findsNothing);
    });

    testWidgets('not without a rewind service above it', (tester) async {
      await pumpCard(tester, tool: 'write', output: written, withScope: false);
      expect(find.text('Undo this write'), findsNothing);
    });
  });

  group('the confirmation', () {
    testWidgets(
      'is asked from the preview and names each file with its reason',
      (tester) async {
        nextPreview = const [
          RewindFile(path: 'a.dart', deletes: false),
          RewindFile(path: 'new.dart', deletes: true),
          RewindFile(
            path: 'b.dart',
            deletes: false,
            blockedBy: RewindSkipReason.changedOutsideAgent,
          ),
        ];
        await pumpCard(tester, tool: 'write', output: written);
        await openConfirmation(tester);

        expect(previews, ['c1']);
        expect(find.text('Go back to before this write?'), findsOneWidget);
        expect(find.textContaining('Restores a.dart'), findsOneWidget);
        expect(find.textContaining('Deletes new.dart'), findsOneWidget);
        expect(
          find.textContaining('Leaves alone b.dart · edited outside the agent'),
          findsOneWidget,
        );
        // Asked, not done: nothing reaches the store until the user says so.
        expect(rewinds, isEmpty);
      },
    );

    testWidgets('cancelling leaves the store untouched', (tester) async {
      nextPreview = const [RewindFile(path: 'a.dart', deletes: false)];
      await pumpCard(tester, tool: 'write', output: written);
      await openConfirmation(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(rewinds, isEmpty);
    });

    testWidgets('nothing to go back to is said instead of asked', (
      tester,
    ) async {
      nextPreview = const [];
      await pumpCard(tester, tool: 'write', output: written);
      await tester.tap(find.text('Undo this write'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing left to undo.'), findsOneWidget);
      expect(find.text('Go back to before this write?'), findsNothing);
      expect(rewinds, isEmpty);
    });
  });

  group('after the rewind', () {
    testWidgets('the report is the store\'s, in the confirmation\'s words', (
      tester,
    ) async {
      nextPreview = const [
        RewindFile(path: 'a.dart', deletes: false),
        RewindFile(path: 'b.dart', deletes: false),
      ];
      nextReport = const RewindReport(
        restored: ['a.dart'],
        deleted: [],
        skipped: [RewindSkip('b.dart', RewindSkipReason.imageUnavailable)],
      );
      await pumpCard(tester, tool: 'write', output: written);
      await openConfirmation(tester);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();

      expect(rewinds, ['c1']);
      expect(find.textContaining('Restores a.dart'), findsOneWidget);
      expect(find.textContaining('Leaves alone b.dart'), findsOneWidget);
      // The one word the two share must not be the preview's: 'Deletes' belongs
      // to a file nothing removed.
      expect(find.textContaining('Deletes'), findsNothing);
    });

    testWidgets('a rewind that touched nothing says so', (tester) async {
      nextPreview = const [
        RewindFile(
          path: 'a.dart',
          deletes: false,
          blockedBy: RewindSkipReason.changedOutsideAgent,
        ),
      ];
      await pumpCard(tester, tool: 'write', output: written);
      await openConfirmation(tester);
      await tester.tap(find.text('Go back'));
      await tester.pumpAndSettle();

      expect(rewinds, ['c1']);
      expect(find.text('Nothing left to undo.'), findsOneWidget);
    });
  });
}
