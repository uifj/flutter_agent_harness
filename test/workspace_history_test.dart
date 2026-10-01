// 本文件守住的那句话：代理模式的历史真的按工作区分成组——一个文件夹一个组头，
// 组头能折叠、能就地新建、能移除；会话行说"多久以前"、能置顶、能删除，
// 而删除只是把行从列表里拿走，不碰快照。
//
// 分组规则本身在 `session_groups_test.dart` 里当纯函数钉；这一棵守的是**画出来的
// 那一棵**：折叠的组不建行、行右侧是相对时间、菜单只在点开之后才在树里。

import 'dart:io';

import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_harness/model/conversation.dart';
import 'package:agent_harness/model/workbench_prefs.dart';
import 'package:agent_harness/state/session_index.dart';
import 'package:agent_harness/state/session_registry.dart';
import 'package:agent_harness/ui/layout/columns.dart';
import 'package:agent_harness/theme/dsw_theme.dart';
import 'package:agent_harness/ui/sidebar/sidebar.dart';

import 'fake_turn_source.dart';

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

  setUp(() {
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

  final folded = <String>[];
  final created = <String>[];
  final removed = <String>[];
  final trees = <String>[];

  Future<void> pump(
    WidgetTester tester, {
    Set<String> collapsed = const {},
    String? currentWorkspace,
    List<String> knownWorkspaces = const [],
    bool flat = false,
    List<HistoryOrganize>? organizes,
    List<Set<String>>? foldSets,
  }) async {
    // The index fills itself from a scan, so every mount here starts from a
    // fresh one — the same order the app reaches the list in.
    await index.refresh();
    await tester.pumpWidget(
      MaterialApp(
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

  testWidgets('the group menu offers the tree, the reveal and the removal', (
    tester,
  ) async {
    source.sessions = [session('a', workspaceRoot: '/work/alpha')];
    await pump(tester);

    await tester.tap(find.byTooltip('Workspace actions'));
    await tester.pumpAndSettle();
    expect(find.text('Show file tree'), findsOneWidget);
    expect(find.text('Remove from list'), findsOneWidget);

    await tester.tap(find.text('Show file tree'));
    await tester.pumpAndSettle();
    expect(trees, ['/work/alpha']);
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
    expect(find.text('Reveal in Finder'), findsOneWidget);

    await tester.tap(find.text('Pin to top'));
    await tester.pumpAndSettle();
    expect(registry.pinnedAt('a'), isNotNull);
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
    expect(find.text('Reveal in Finder'), findsNothing);
  });

  testWidgets('flat mode draws the old list with no headers at all', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];

    await pump(tester, flat: true);

    expect(find.text('Workspaces'), findsNothing);
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

  testWidgets('collapse all folds every group, expand all unfolds them', (
    tester,
  ) async {
    source.sessions = [
      session('a', workspaceRoot: '/work/alpha'),
      session('c', workspaceRoot: '/work/beta', minutesAgo: 5),
    ];
    final sets = <Set<String>>[];

    await pump(tester, foldSets: sets);

    await tester.tap(find.byTooltip('History view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collapse all'));
    await tester.pumpAndSettle();
    expect(sets.single, {'/work/alpha', '/work/beta'});

    await tester.tap(find.byTooltip('History view'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand all'));
    await tester.pumpAndSettle();
    expect(sets.last, isEmpty);
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
