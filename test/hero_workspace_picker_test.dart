// The hero's workspace picker: the empty conversation's one control.
//
// What is under test is the seam, not the paint: the picker must show the
// folder the scope knows about, must offer the recents plus a way out to the
// platform dialog, and must disappear rather than break when no host mounted
// the scope. The adopting itself is the app's to do — here it is only asserted
// that the right callback leaves with the right path.

import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/conversation/hero_workspace_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    String? workspaceRoot,
    List<String> recent = const [],
    Future<void> Function()? onPick,
    Future<void> Function(String path)? onAdopt,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: dswThemeData(Brightness.light),
      home: Scaffold(
        body: Center(
          child: HeroWorkspaceScope(
            workspaceRoot: workspaceRoot,
            recent: recent,
            onPick: onPick ?? () async {},
            onAdopt: onAdopt,
            child: const HeroWorkspacePicker(),
          ),
        ),
      ),
    ),
  );

  testWidgets('without a scope the picker hides itself', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dswThemeData(Brightness.light),
        home: const Scaffold(body: Center(child: HeroWorkspacePicker())),
      ),
    );

    // The seat is the app's to mount; a missing host is a missing control,
    // not an error — the picker renders nothing at all.
    expect(find.byType(HeroWorkspacePicker), findsOneWidget);
    expect(find.text('Choose a workspace folder'), findsNothing);
  });

  testWidgets('no folder and no recents: the pick call is the whole row', (
    tester,
  ) async {
    var picks = 0;
    await pump(tester, onPick: () async => picks++);

    await tester.tap(find.text('Choose a workspace folder'));
    await tester.pump();
    expect(picks, 1);
  });

  testWidgets('an adopted folder wears its name and opens the menu', (
    tester,
  ) async {
    await pump(tester, workspaceRoot: '/tmp/proj', recent: ['/tmp/proj']);

    // The capsule shows the folder, not the path: the hero is the first
    // screen, and a basename is a label a user can read at a glance.
    expect(find.text('proj'), findsOneWidget);

    await tester.tap(find.text('proj'));
    await tester.pumpAndSettle();

    // The menu offers the recents and the footer — the source's
    // menu-plus-footer shape.
    expect(find.text('/tmp/proj'), findsOneWidget);
    expect(find.text('Choose a folder…'), findsOneWidget);
  });

  testWidgets('a recent is adopted with its whole path', (tester) async {
    String? adopted;
    await pump(
      tester,
      workspaceRoot: '/tmp/proj',
      recent: ['/tmp/proj', '/tmp/other'],
      onAdopt: (path) async => adopted = path,
    );

    await tester.tap(find.text('proj'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/tmp/other'));
    await tester.pumpAndSettle();

    expect(adopted, '/tmp/other');
  });

  testWidgets('the menu footer routes to the platform picker', (tester) async {
    var picks = 0;
    await pump(
      tester,
      workspaceRoot: '/tmp/proj',
      recent: ['/tmp/proj'],
      onPick: () async => picks++,
    );

    await tester.tap(find.text('proj'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose a folder…'));
    await tester.pumpAndSettle();

    expect(picks, 1);
  });

  testWidgets('recents without a folder still open the menu', (tester) async {
    String? adopted;
    await pump(
      tester,
      recent: ['/tmp/one'],
      onAdopt: (path) async => adopted = path,
    );

    // The capsule falls back to the pick call's label but keeps the menu —
    // the recents are one tap from being the workspace again.
    await tester.tap(find.text('Choose a workspace folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('/tmp/one'));
    await tester.pumpAndSettle();

    expect(adopted, '/tmp/one');
  });
}
