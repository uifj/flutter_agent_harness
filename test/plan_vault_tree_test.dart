// ADR-0073 guards: the vault tree lives in the sidebar and persists across
// every plan screen — the collection/library views no longer take it away.
// The file-system facts are the contract: what gets listed, what a save
// writes, what a discard loses — fakes would prove nothing.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planstar/l10n/app_localizations.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart' show dswShadTheme;
import 'package:shadcn_ui/shadcn_ui.dart' show ShadTheme;
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/plan/plan_vault_tree.dart';

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('dsh_plan_tree_');
    File('${root.path}/readme.md').writeAsStringSync('# Readme\n');
    Directory('${root.path}/notes').createSync();
    File('${root.path}/notes/idea.md').writeAsStringSync('An idea\n');
    File('${root.path}/data.txt').writeAsStringSync('not markdown');
  });

  tearDown(() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      try {
        root.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    }
  });

  Future<void> pump(WidgetTester tester, {String? selected}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: PlanVaultTree(
            workspaceRoot: root.path,
            selectedPath: selected,
            onOpenNote: (entry) {},
          ),
        ),
      ),
    );
    // The vault index is a compute isolate — real time until it lands.
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text('readme.md').evaluate().isNotEmpty) return;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
  }

  testWidgets('lists only the markdown files, folder as the second line', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('readme.md'), findsOneWidget);
    expect(find.text('idea.md'), findsOneWidget);
    // The folder shows twice by design: the directory row's name and the
    // idea.md row's quieter second line. (This exact double-match was the
    // registered macOS baseline failure of the old host — fixed here by
    // asserting the truth instead of pretending one.)
    expect(find.text('notes'), findsNWidgets(2));
    expect(find.text('data.txt'), findsNothing);
  });

  testWidgets('tapping a note hands the entry to the host', (tester) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: PlanVaultTree(
            workspaceRoot: root.path,
            onOpenNote: (entry) => opened.add(entry.relative),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.text('readme.md').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    await tester.tap(find.text('readme.md'));
    await tester.pump();
    expect(opened, ['readme.md']);
  });

  testWidgets('new note creates the file and asks the host to open it', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),

        builder: (context, child) => ShadTheme(
          data: dswShadTheme(Theme.of(context).brightness),
          child: child!,
        ),
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: PlanVaultTree(
            workspaceRoot: root.path,
            onOpenNote: (entry) => opened.add(entry.relative),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 100; attempt++) {
      if (find.byTooltip('New Note').evaluate().isNotEmpty) break;
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    await tester.tap(find.byTooltip('New Note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'fresh');
    await tester.pump();
    // The whole completion chain is real IO (dialog pop → writeAsString →
    // compute re-index → host callback), none of which completes in the
    // fake-async zone — hand the loop over until the callback lands.
    await tester.runAsync(() async {
      await tester.tap(find.text('Create'));
      // The suspended create coroutine resumes on fake-time elapse; the
      // pumps below are what let it run to the host callback.
      for (var attempt = 0; attempt < 50 && opened.isEmpty; attempt++) {
        await tester.pump(const Duration(milliseconds: 20));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(File('${root.path}/fresh.md').existsSync(), isTrue);
    expect(opened, ['fresh.md']);
  });
}
