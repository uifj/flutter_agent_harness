// The one sentence this file holds: `AppScope.save` brings the runtime in line
// with the saved document by the exact rule the tree depends on — a
// workspace-only change re-points the live runtime (no rebuild), while a change
// to the model fields, the MCP set, or the skills directory rebuilds it.
//
// This is the ADR-0002 Stage 4 guard. The runtime swap is the one piece of the
// composition root that no single controller can do and that riverpod's
// auto-dispose cannot order safely (the old runtime is disposed LAST, after the
// controllers adopt the new one — see `app_scope.save`). Before that chain is
// touched, these tests pin its observable contract so a provider-isation that
// changes the rebuild trigger, leaks a runtime, or drops the live workspace
// setter fails here rather than silently in the streaming path.
//
// The teardown ordering itself is not assertable from outside (no disposed flag
// on the runtime); it stays guarded by `conversation_controller_test.dart`'s
// streaming contract and by review.

import 'dart:io';

import 'package:agent_harness/model/app_settings.dart';
import 'package:agent_harness/state/app_scope.dart';
import 'package:agent_harness/state/prefs_store.dart';
import 'package:agent_harness/state/settings_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory support;
  late SettingsStore settings;
  late PrefsStore prefs;
  late AppScope scope;

  setUp(() async {
    support = Directory.systemTemp.createTempSync('dsh_scope_');
    settings = await SettingsStore.open(support);
    prefs = await PrefsStore.open(support);
    scope = AppScope(support: support, settings: settings, prefs: prefs);
  });

  tearDown(() async {
    scope.dispose();
    support.deleteSync(recursive: true);
  });

  test(
    'a workspace-only save re-points the live runtime, no rebuild',
    () async {
      final before = scope.runtime;
      await scope.save(settings.value.withWorkspace(support.path));

      // Same instance: the workspace is a live setter, not a restart trigger.
      expect(scope.runtime, same(before));
      expect(scope.runtime.workspaceRoot, support.path);
    },
  );

  test('a model-field change rebuilds the runtime', () async {
    final before = scope.runtime;
    await scope.save(
      settings.value.copyWith(
        model: settings.value.model.copyWith(model: 'a-different-model'),
      ),
    );

    // A new runtime: the model is baked into the registered agent.
    expect(scope.runtime, isNot(same(before)));
  });

  test('selectModel routes through the same rebuild', () async {
    final before = scope.runtime;
    await scope.selectModel('yet-another-model');
    expect(scope.runtime, isNot(same(before)));
    // The document the runtime was built from carries the chosen model.
    expect(settings.value.model.model, 'yet-another-model');
  });

  test('a skills-directory change rebuilds the runtime', () async {
    final before = scope.runtime;
    await scope.save(settings.value.copyWith(skillsRoot: support.path));
    expect(scope.runtime, isNot(same(before)));
  });

  test('an appearance-only change does NOT rebuild the runtime', () async {
    // ADR-0005 rides the same document; appearance prefs must never tear down
    // the runtime. This is the guard that keeps the settings-save and the
    // runtime-restart rules from drifting apart.
    final before = scope.runtime;
    await scope.save(
      settings.value.copyWith(conversationWidth: AppConversationWidth.wide),
    );
    expect(scope.runtime, same(before));
  });

  test('opening a conversation adopts the folder it was started in', () async {
    // Its own host: the sidecar row has to be on disk before the scope opens it.
    final root = Directory.systemTemp.createTempSync('app_scope_folder');
    // A real folder — the runtime resolves the workspace through the same guard
    // the file tools use, so a made-up path is not something it can open.
    final other = Directory.systemTemp.createTempSync('app_scope_elsewhere');
    final sessions = Directory('${root.path}/sessions')..createSync();
    File(
      '${sessions.path}/sessions.json',
    ).writeAsStringSync('{"s-elsewhere": {"workspaceRoot": "${other.path}"}}');
    final scoped = AppScope(
      support: root,
      settings: await SettingsStore.open(root),
      prefs: await PrefsStore.open(root),
    );
    addTearDown(() {
      scoped.dispose();
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (other.existsSync()) other.deleteSync(recursive: true);
    });
    final before = scoped.settings.value.workspaceRoot;

    // No snapshot exists behind either id, and genkit says so by throwing. The
    // guard is about what happened *before* that: `openSession` adopts the
    // folder first, so a conversation the sidecar owns is read with the tools
    // pointed at its own files, not at whatever folder was open before the row
    // was clicked.
    await expectLater(scoped.openSession('s-unlisted'), throwsStateError);
    // A conversation with no ownership row claims no folder — the history
    // written before ADR-0039 has none, and moving the workspace on a hunch
    // would be a second way to be in the wrong place.
    expect(scoped.settings.value.workspaceRoot, before);

    await expectLater(scoped.openSession('s-elsewhere'), throwsStateError);
    // Document, live runtime and workbench all move together: `save` is the one
    // path that changes folders (ADR-0039), and it is what keeps the approvals
    // book, the rewind history and the file tree on the same side of the move.
    expect(scoped.settings.value.workspaceRoot, other.path);
    expect(
      scoped.runtime.workspaceRoot,
      other.resolveSymbolicLinksSync(),
      reason: "the tools answer about the transcript's own folder",
    );
    expect(scoped.workbench.workspaceRoot, other.path);
  });
}
