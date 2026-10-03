// 本文件守住的那句话：代理模式的历史真的按工作区分成组——一个文件夹一个组头，
// 组头能折叠、能就地新建、能移除；会话行说"多久以前"、能置顶、能删除，
// 而删除只是把行从列表里拿走，不碰快照。
//
// 分组规则本身在 `session_groups_test.dart` 里当纯函数钉；这一棵守的是**画出来的
// 那一棵**：折叠的组不建行、行右侧是相对时间、菜单只在点开之后才在树里，
// 而侧车存不下的那一次改动要在动手的那一下就说出来。

import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton, PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:planstar/model/conversation.dart';
import 'package:planstar/model/workbench_prefs.dart';
import 'package:planstar/state/session_index.dart';
import 'package:planstar/state/session_registry.dart';
import 'package:planstar/ui/layout/columns.dart';
import 'package:planstar/theme/dsw_alias.dart';
import 'package:planstar/theme/dsw_shad_bridge.dart';
import 'package:planstar/theme/dsw_theme.dart';
import 'package:planstar/ui/sidebar/sidebar.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'fake_turn_source.dart';
import 'clipboard_probe.dart';

/// The clock the rows are written against. `formatRelativeTime` reads
/// `DateTime.now()` at paint time, so a fixed 2026 date would land in the future
/// and every row would answer "just now".
final _now = DateTime.now();

void main() {
  late Directory support;
  late SessionRegistry registry;
  late FakeTurnSource source;
  late SessionIndex index;

  SessionSummary session(
    String id, {
    String? workspaceRoot,
    int minutesAgo = 0,
  }) => SessionSummary(
    id: id,
    updatedAt: _now.subtract(Duration(minutes: minutesAgo)),
    title: 'session $id',
    workspaceRoot: workspaceRoot,
  );

  final folded = <String>[];
  final created = <String>[];
  final removed = <String>[];
  final trees = <String>[];

  setUp(() {
    // These collectors are per-file and every guard asserts them with exact
    // equality — left over from the previous test, a guard would read another
    // test's gesture as its own. (This is how the removal guard first failed: it
    // saw the earlier header tap in `folded`, not anything it had done.)
    folded.clear();
    created.clear();
    removed.clear();
    trees.clear();
    support = Directory.systemTemp.createTempSync('workspace_history');
    registry = SessionRegistry.open(support);
    source = FakeTurnSource();
    index = SessionIndex(source, registry: registry);
  });

  tearDown(() {
    index.dispose();
    registry.dispose();
    if (support.existsSync()) support.deleteSync(recursive: true);
  });

  Future<void> pump(
    WidgetTester tester, {
    Set<String> collapsed = const {},
    String? currentWorkspace,
    List<String> knownWorkspaces = const [],
    bool flat = false,
    List<HistoryOrganize>? organizes,
    List<Set<String>>? foldSets,
    bool withStrip = false,
  }) async {
    // The index fills itself from a scan, so every mount here starts from a
    // fresh one — the same order the app reaches the list in.
    await index.refresh();
    await tester.pumpWidget(
      MaterialApp(
        // `main.dart`'s seam: the host for the app's one feedback surface sits
        // above the Navigator, and takes its colours from the bridge.
        builder: withStrip
            ? (context, child) => ShadTheme(
                data: dswShadTheme(Brightness.light),
                child: ShadSonner(child: child!),
              )
            : null,
        theme: dswThemeData(Brightness.light),
        home: Scaffold(
          body: Row(
            children: [
              ClipRect(
                child: SizedBox(
                  width: sidebarDefault,
                  child: Sidebar(
                    collapsed: false,
                    width: sidebarDefault,
                    sessions: index,
                    onNewSession: () {},
                    onToggle: () {},
                    onOpenSession: (_) {},
                    onOpenSettings: () {},
                    onToggleDetails: () {},
                    detailsOpen: false,
                    currentWorkspace: currentWorkspace,
                    knownWorkspaces: knownWorkspaces,
                    historyOrganize: flat
                        ? HistoryOrganize.flat
                        : HistoryOrganize.project,
                    collapsedWorkspaces: collapsed,
                    onToggleWorkspaceCollapsed: folded.add,
                    onNewSessionInWorkspace: created.add,
                    onRemoveWorkspace: removed.add,
                    onOpenWorkspaceTree: trees.add,
                    onAddWorkspace: () {},
                    onHistoryOrganizeChanged: organizes == null
                        ? null
                        : (value) => organizes.add(value),
                    onSetCollapsedWorkspaces: foldSets == null
                        ? null
                        : (keys) => foldSets.add(keys),
                  ),
                ),
              ),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The two header labels, topmost first.
  List<String> headerOrder(WidgetTester tester) {
    final found = <String, double>{};
    for (final label in ['alpha', 'beta', 'Unassigned']) {
      if (find.text(label).evaluate().isEmpty) continue;
      found[label] = tester.getTopLeft(find.text(label)).dy;
    }
    return (found.entries.toList()..sort((a, b) => a.value.compareTo(b.value)))
        .map((entry) => entry.key)
        .toList();
  }

  testWidgets('one folder per header, with its conversations under it', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('b', workspaceRoot: '/work/alpha', minutesAgo: 30),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];

    await pump(tester);

    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
    expect(find.text('session a'), findsOneWidget);
    expect(find.text('session c'), findsOneWidget);
  });

  testWidgets('the folder the user is in leads, whatever its age', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha', minutesAgo: 600),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];

    await pump(tester, currentWorkspace: '/work/alpha');

    expect(headerOrder(tester), ['alpha', 'beta']);
  });

  testWidgets('a folded group keeps its header and builds no rows', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];

    await pump(tester, collapsed: {'/work/alpha'});

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('session a'), findsNothing);
    expect(find.text('session c'), findsOneWidget);
  });

  testWidgets('tapping a header folds that folder, and names it', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];

    await pump(tester);
    await tester.tap(find.text('alpha'));
    await tester.pumpAndSettle();

    expect(folded, ['/work/alpha']);
  });

  testWidgets('a folder with no conversation yet still gets a row', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];

    await pump(tester, knownWorkspaces: ['/work/gamma']);

    expect(find.text('gamma'), findsOneWidget);
    expect(find.text('session a'), findsOneWidget);
  });

  testWidgets('the row says how long ago in the app’s own words', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha', minutesAgo: 59),
    ];

    await pump(tester);

    expect(find.text('59m'), findsOneWidget);
  });

  testWidgets('a pinned conversation sits above a newer one', (tester) async {
    source.sessions = [
      session('fresh', workspaceRoot: '/work/alpha', minutesAgo: 1),
      session('stuck', workspaceRoot: '/work/alpha', minutesAgo: 600),
    ];
    registry.setPinned('stuck', true, now: _now);

    await pump(tester);

    final freshTop = tester.getTopLeft(find.text('session fresh')).dy;
    final stuckTop = tester.getTopLeft(find.text('session stuck')).dy;
    expect(stuckTop, lessThan(freshTop));
  });

  testWidgets('deleting a row leaves the snapshot listing alone', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];
    await pump(tester);
    expect(find.text('session a'), findsOneWidget);

    index.remove('a');
    await tester.pumpAndSettle();

    expect(find.text('session a'), findsNothing);
    expect(registry.isDeleted('a'), isTrue);
    expect(
      source.sessions.map((s) => s.id),
      ['a'],
      reason: 'a tombstone is not a removal — the runtime still lists it',
    );
  });

  testWidgets(
    'the group menu offers the tree, the path, the reveal and the removal',
    (tester) async {
      // The probe answers the clipboard channel; the real messenger never would,
      // and the copy's await would hang the test.
      final clipboard = ClipboardProbe(tester.binding.defaultBinaryMessenger);
      source.sessions = [session('a', workspaceRoot: '/work/alpha')];
      await pump(tester);

      await tester.tap(find.byTooltip('Workspace actions'));
      await tester.pumpAndSettle();
      expect(find.text('Show file tree'), findsOneWidget);
      expect(find.text('Copy workspace path'), findsOneWidget);
      expect(find.text('Reveal in file manager'), findsOneWidget);
      expect(find.text('Remove from list'), findsOneWidget);

      await tester.tap(find.text('Show file tree'));
      await tester.pumpAndSettle();
      expect(trees, ['/work/alpha']);

      // The path the group is named after is the thing a user pastes elsewhere,
      // so it is read from the clipboard rather than assumed from the row.
      await tester.tap(find.byTooltip('Workspace actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Copy workspace path'));
      await tester.pumpAndSettle();
      expect(clipboard.text, '/work/alpha');
    },
  );

  // The group header's `+` is how a folder that is not the current one gets a
  // conversation of its own (upstream `onStartDraftInWorkspace`,
  // `WorkspaceSidebarItem.tsx:344`). The harness wired it and no assertion ever
  // pressed it — the inverse of ADR-0041's "tested verb with no door": here the
  // door exists and nothing walks through it, so a wrong folder handed over
  // would ship unnoticed.
  testWidgets(
    "a folder group's + starts a conversation in that folder, 未归属 has none",
    (tester) async {
      source.sessions = [
        session('a', workspaceRoot: '/work/alpha'),
        session('b', workspaceRoot: '/work/beta'),
        session('c'),
      ];
      await pump(tester);

      // Three group rows, two `+`: the unassigned bucket names no folder, so
      // starting a conversation in it would be a promise the app cannot keep.
      expect(find.text('Unassigned'), findsOneWidget);
      expect(find.byTooltip('New session'), findsNWidgets(2));

      // The last `+` is beta's (alpha's group leads, the unassigned row
      // contributes none), and the only thing that matters is which folder the
      // row hands over.
      await tester.tap(find.byTooltip('New session').last);
      await tester.pumpAndSettle();

      expect(created, ['/work/beta']);
    },
  );

  // Upstream documents the failure this guard exists for, in its own source: in a
  // collapsed group, clicking "remove" first reached the row's open handler, so
  // the workspace was re-added instead of removed (`WorkspaceSidebarItem.tsx:
  // 334-340` - "表现为删不掉", fixed there by swallowing the click at the menu
  // layer). Here the menu button is a sibling of the fold's tap target, and
  // `removed` had been collected by the harness without ever being asserted.
  testWidgets(
    'removing a group hands over its own folder, and folds nothing on the way',
    (tester) async {
      source.sessions = [
        session('a', workspaceRoot: '/work/alpha'),
        session('b', workspaceRoot: '/work/beta'),
      ];
      await pump(tester);

      await tester.tap(find.byTooltip('Workspace actions').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove from list'));
      await tester.pumpAndSettle();

      expect(removed, ['/work/beta']);
      expect(
        folded,
        isEmpty,
        reason: 'one gesture, one fact: removing a group is not also a fold',
      );
    },
  );

  /// The wash a row wears. Hover is painted by its `AnimatedContainer`, selection
  /// by the inner `Container`, and both are read as drawn rather than as widget
  /// arguments: `theme_token_test` already proves the two tokens differ, so what
  /// still needed proving is that this row is the thing that puts them on.
  BoxDecoration? hoverWash(WidgetTester tester, String label) {
    final w = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.text(label),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    return w.decoration is BoxDecoration ? w.decoration as BoxDecoration : null;
  }

  BoxDecoration? selectWash(WidgetTester tester, String label) {
    final w = tester.widget<Container>(
      find
          .ancestor(of: find.text(label), matching: find.byType(Container))
          .first,
    );
    return w.decoration is BoxDecoration ? w.decoration as BoxDecoration : null;
  }

  testWidgets('selected and hovered are two different washes on a row', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('b', workspaceRoot: '/work/alpha', minutesAgo: 5),
    ];
    index.setActive('a');
    await pump(tester);

    expect(
      selectWash(tester, 'session a')?.color,
      DswAlias.light.interactiveSelected,
    );
    expect(hoverWash(tester, 'session a')?.color, isNull);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    await pointer.moveTo(tester.getCenter(find.text('session b')));
    await tester.pumpAndSettle();

    final hovered = hoverWash(tester, 'session b')?.color;
    expect(hovered, DswAlias.light.interactiveBgHover);
    expect(
      hovered,
      isNot(DswAlias.light.interactiveSelected),
      reason:
          'ADR-0017 S2: a pointer passing over must not read as "this one is open"',
    );

    await pointer.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(
      hoverWash(tester, 'session b')?.color,
      isNull,
      reason: 'and it lifts',
    );
  });

  testWidgets('a conversation right-click can pin, rename and delete', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];
    await pump(tester);

    await tester.tap(find.text('session a'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Pin to top'), findsOneWidget);
    expect(find.text('Rename'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Copy session id'), findsOneWidget);
    expect(find.text('Reveal in file manager'), findsOneWidget);

    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(registry.pinnedAt('a'), isNotNull);
  });

  // The strip dismisses itself on a timer; a run outlives any default so the
  // tree never goes away with it still pending.
  Future<void> expire(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
  }

  testWidgets('a pin the sidecar could not keep says so', (tester) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];
    // Nothing can move into the slot the document wants.
    Directory('${support.path}/sessions.json').createSync();

    await pump(tester, withStrip: true);
    await tester.tap(find.text('session a'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to top'));
    await tester.pump();

    expect(registry.pinnedAt('a'), isNotNull, reason: 'the list still answers');
    expect(index.metadataError, isNotNull);
    expect(
      find.text('The list changed, but that could not be saved'),
      findsOneWidget,
    );
    expect(
      tester.widget<ShadToast>(find.byType(ShadToast)).variant,
      ShadToastVariant.destructive,
    );

    await expire(tester);
  });

  testWidgets('a pin the sidecar kept stays quiet', (tester) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];

    await pump(tester, withStrip: true);
    await tester.tap(find.text('session a'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to top'));
    await tester.pump();

    expect(index.metadataError, isNull);
    expect(find.byType(ShadToast), findsNothing);
  });

  testWidgets('a row with no folder offers no path to reveal', (tester) async {
    source.sessions = [session('nobody')];

    await pump(tester);
    await tester.tap(find.text('Unassigned'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('session nobody'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Copy session id'), findsOneWidget);
    expect(find.text('Copy workspace path'), findsNothing);
    expect(find.text('Reveal in file manager'), findsNothing);
  });

  testWidgets('flat mode lists conversations with no group headers, and keeps '
      'its section head', (tester) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];

    await pump(tester, flat: true);

    // What 平铺 drops is the *group* headers. The section head stays because the
    // `⋮` inside it is the app's only writer of this preference — a head that
    // disappears in the view it leaves behind is a one-way door. (This line used
    // to assert `findsNothing`, which pinned that door.)
    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('alpha'), findsNothing);
    expect(find.text('session a'), findsOneWidget);
    expect(find.text('session c'), findsOneWidget);
  });

  testWidgets('the section menu is the only place the arrangement changes', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];
    final chosen = <HistoryOrganize>[];

    await pump(tester, organizes: chosen);

    await tester.tap(find.byTooltip('History view'));
    await tester.pumpAndSettle();
    expect(find.text('Group by workspace'), findsOneWidget);
    expect(find.text('Flat list'), findsOneWidget);

    await tester.tap(find.text('Flat list'));
    await tester.pumpAndSettle();
    expect(chosen, [HistoryOrganize.flat]);
  });

  // The head carries ONE glyph that reads the fold state, as upstream does
  // (`WorkspaceSidebar.tsx:1074-1095`: Minimize2 while anything is expanded,
  // Maximize2 once everything is folded). Two menu rows can both be pressed
  // without knowing which one matches the list; one glyph cannot be wrong about
  // what the user is looking at.
  testWidgets('the head glyph folds every group, then reads as unfold', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];
    final sets = <Set<String>>[];

    await pump(tester, foldSets: sets);

    expect(find.byTooltip('Collapse all'), findsOneWidget);
    await tester.tap(find.byTooltip('Collapse all'));
    await tester.pumpAndSettle();
    expect(sets.single, {'/work/alpha', '/work/beta'});

    // The same control after the list changed: it now offers the opposite,
    // because the state it shows is the state of the groups.
    await pump(
      tester,
      foldSets: sets,
      collapsed: {'/work/alpha', '/work/beta'},
    );
    expect(
      find.byTooltip('Collapse all'),
      findsNothing,
      reason: 'nothing left to fold, so nothing offered',
    );
    await tester.tap(find.byTooltip('Expand all'));
    await tester.pumpAndSettle();
    expect(sets.last, isEmpty);
  });

  testWidgets('the flat view keeps its head — that menu is the only way back — '
      'and sheds the fold glyph', (tester) async {
    // "Flat" is not "no groups right now", it is "never any groups", so the one
    // control that could never answer is not drawn (upstream's own visibility
    // rule, `WorkspaceSidebar.tsx:854-857`). The head itself must stay: the `⋮`
    // is the only writer of this preference anywhere in the app, so a head that
    // disappears in the view it leaves behind is a one-way door.
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];
    final sets = <Set<String>>[];
    final chosen = <HistoryOrganize>[];

    await pump(tester, flat: true, foldSets: sets, organizes: chosen);

    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.byTooltip('Collapse all'), findsNothing);
    expect(find.byTooltip('Expand all'), findsNothing);

    await tester.tap(find.byTooltip('History view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Group by workspace'));
    await tester.pumpAndSettle();
    expect(chosen, [
      HistoryOrganize.project,
    ], reason: 'the flat view can hand the view back');
  });

  testWidgets('an empty grouped view carries a dead glyph, not a missing one', (
    tester,
  ) async {
    // Rows can arrive without the view changing, so the seat stays and says it
    // cannot be used — a control that vanishes is a missing control.
    final sets = <Set<String>>[];
    source.sessions = [];
    await pump(tester, foldSets: sets);

    final glyph = find.byTooltip('Collapse all');
    expect(glyph, findsOneWidget);
    await tester.tap(glyph);
    await tester.pumpAndSettle();
    expect(sets, isEmpty, reason: 'nothing to fold yet, so it answers nothing');
  });

  testWidgets('the sidecar, not the snapshot, is what puts a row under its '
      'folder — the path production actually takes', (tester) async {
    // `listSessions` cannot report a folder: genkit owns that document. Every
    // real row therefore arrives with no workspace and gets one only from
    // `sessions.json`. Testing the source field alone would pass while the
    // shipped path was broken.
    source.sessions = [
      SessionSummary(id: 'a', updatedAt: _now, title: 'session a'),
    ];
    registry.noteWorkspace('a', '/work/from-sidecar');

    await pump(tester);

    expect(find.text('from-sidecar'), findsOneWidget);
    expect(find.text('Unassigned'), findsNothing);
  });

  testWidgets('a rename from the sidecar wins over the derived title, once', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];

    await pump(tester);
    expect(find.text('session a'), findsOneWidget);

    index.rename('a', '改过的名字');
    await tester.pumpAndSettle();

    expect(find.text('改过的名字'), findsOneWidget);
    expect(find.text('session a'), findsNothing);
    expect(
      source.sessions.single.title,
      'session a',
      reason:
          'the override lives in the sidecar; the snapshot keeps its own truth',
    );
  });

  testWidgets('an empty history still says so under the section head', (
    tester,
  ) async {
    source.sessions = [];

    await pump(tester);

    expect(find.text('Workspaces'), findsOneWidget);
    expect(find.text('No sessions yet'), findsOneWidget);
  });

  testWidgets('a session with no folder lands in the unassigned bucket', (
    tester,
  ) async {
    source.sessions = [
      session('nobody'),
      session('a', workspaceRoot: '/work/alpha', minutesAgo: 30),
    ];

    await pump(tester);

    expect(find.text('Unassigned'), findsOneWidget);
    expect(headerOrder(tester), ['alpha', 'Unassigned']);
  });
}
