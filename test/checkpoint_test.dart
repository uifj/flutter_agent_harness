// What a checkpoint must never get wrong: it restores the bytes it promised, it
// refuses when it would overwrite somebody else, and it stops pretending about
// files it cannot see (ADR-0014).
//
// Real temp directories, not fakes: existence, bytes and rename-over-target are
// filesystem facts. The paths are always taken from `Workspace.resolve`, so a
// macOS temp dir reached through /var cannot make a test disagree with the store
// about which file is which.

import 'dart:convert';
import 'dart:io';

import 'package:agent_harness/model/checkpoint.dart';
import 'package:agent_harness/model/workspace.dart';
import 'package:agent_harness/state/checkpoint_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory support;
  late Directory root;
  late Workspace workspace;
  late CheckpointStore store;

  /// The conversation these tests record under. A rewind scoped to a
  /// conversation needs one named, exactly as `AppScope` names the live token.
  const conv = 'this-conversation';

  setUp(() {
    support = Directory.systemTemp.createTempSync('cp_support_');
    root = Directory.systemTemp.createTempSync('cp_ws_');
    workspace = Workspace.of(root.path);
    store = CheckpointStore.open(support)
      ..useWorkspace(root.path)
      ..conversation = conv;
  });

  tearDown(() {
    store.dispose();
    support.deleteSync(recursive: true);
    root.deleteSync(recursive: true);
  });

  void write(String relative, String content) =>
      File(workspace.resolve(relative)).writeAsStringSync(content);

  String read(String relative) =>
      File(workspace.resolve(relative)).readAsStringSync();

  bool exists(String relative) =>
      File(workspace.resolve(relative)).existsSync();

  /// Does what a write tool does, in the order it does it: the bytes that were
  /// there, the bytes that land, then the record. Reading the disk for the
  /// before-image is the tool's job, so the before-image here is whatever the
  /// file actually held — which is what makes the conflict guard testable.
  FileCheckpoint record(
    String relative, {
    String? before,
    required String after,
    CheckpointStore? into,
  }) {
    final target = into ?? store;
    if (before != null) write(relative, before);
    final image = before == null ? null : utf8.encode(before);
    write(relative, after);
    return target.record(
      path: relative,
      after: utf8.encode(after),
      before: image,
    )!;
  }

  List<RewindFile> preview(String id, {String? conversation}) =>
      store.previewRewind(
        id: id,
        workspace: workspace,
        conversation: conversation ?? conv,
      );

  RewindReport rewind(
    String id, {
    RewindScope scope = RewindScope.conversation,
    String? conversation,
  }) => store.rewindTo(
    id: id,
    workspace: workspace,
    scope: scope,
    conversation: conversation ?? conv,
  );

  String blobPath(String fingerprint) =>
      '${support.path}/checkpoints/blobs/$fingerprint.bin';

  group('the change detector', () {
    test('is stable, and separates content and length', () {
      final a = contentFingerprint(utf8.encode('hello'));
      expect(a, contentFingerprint(utf8.encode('hello')));
      expect(a, isNot(contentFingerprint(utf8.encode('hellO'))));
      expect(a, isNot(contentFingerprint(utf8.encode('hello\n'))));
    });

    test('names bytes rather than a string, so binary survives it', () {
      final bytes = List<int>.generate(256, (i) => i);
      expect(
        contentFingerprint(bytes),
        contentFingerprint(List<int>.from(bytes)),
      );
      expect(
        contentFingerprint(bytes.sublist(0, 255)),
        isNot(contentFingerprint(bytes)),
      );
    });
  });

  group('the index document', () {
    test('survives a reopen, in order', () {
      final first = record('a.dart', after: 'one');
      record('a.dart', before: 'one', after: 'two');

      final reopened = CheckpointStore.open(support);
      addTearDown(reopened.dispose);
      reopened.useWorkspace(root.path);

      expect(reopened.savedFor(root.path), hasLength(2));
      expect(reopened.savedFor(root.path).first.id, first.id);
      expect(
        reopened.savedFor(root.path).last.change,
        CheckpointChange.modified,
      );
    });

    test('drops a row it cannot understand instead of guessing', () {
      record('a.dart', after: 'one');
      final file = File('${support.path}/checkpoints/index.json');
      final doc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final rows = doc.values.first as List;
      rows.add({'id': 'c9', 'conversation': 'x', 'path': 'b.dart'});
      file.writeAsStringSync(jsonEncode(doc));

      final reopened = CheckpointStore.open(support);
      addTearDown(reopened.dispose);
      reopened.useWorkspace(root.path);

      expect(reopened.savedFor(root.path), hasLength(1));
    });

    test('is keyed by workspace, so two folders do not share an undo', () {
      record('a.dart', after: 'one');
      final other = Directory.systemTemp.createTempSync('cp_other_');
      addTearDown(() => other.deleteSync(recursive: true));

      final reopened = CheckpointStore.open(support);
      addTearDown(reopened.dispose);
      expect(reopened.savedFor(other.path), isEmpty);
      expect(reopened.savedFor(root.path), hasLength(1));
    });
  });

  group('capture', () {
    test('a first write is a creation and needs no image', () {
      final entry = record('new.dart', after: 'created');

      expect(entry.change, CheckpointChange.created);
      expect(entry.captured, isTrue);
      expect(entry.beforeFingerprint, isNull);
      expect(entry.beforeBytes, isNull);
    });

    test('a later write stores its before-image as a blob', () {
      final entry = record('a.dart', before: 'old', after: 'new');

      expect(entry.change, CheckpointChange.modified);
      expect(
        File(blobPath(entry.beforeFingerprint!)).readAsStringSync(),
        'old',
      );
    });

    test('identical bytes are stored once', () {
      final first = record('a.dart', before: 'same', after: 'one');
      final second = record('b.dart', before: 'same', after: 'two');

      expect(first.beforeFingerprint, second.beforeFingerprint);
      expect(
        Directory('${support.path}/checkpoints/blobs').listSync(),
        hasLength(1),
      );
    });

    test('an over-large before-image is named but marked uncapturable', () {
      final big = 'x'.padRight(CheckpointStore.maxStoredFileBytes + 1, 'y');
      final entry = record('big.dart', before: big, after: 'small');

      expect(entry.captured, isFalse);
      expect(entry.beforeFingerprint, isNull);

      final report = rewind(entry.id);
      expect(report.restored, isEmpty);
      expect(report.skipped.single.reason, RewindSkipReason.imageUnavailable);
      // Refusing is the whole point: the file the agent shrank stays shrunk.
      expect(read('big.dart'), 'small');
    });
  });

  group('rewind', () {
    test('restores the bytes the agent replaced', () {
      final entry = record('a.dart', before: 'mine', after: 'agent wrote this');
      expect(read('a.dart'), 'agent wrote this');

      final report = rewind(entry.id);

      expect(report.restored, ['a.dart']);
      expect(read('a.dart'), 'mine');
    });

    test('deletes a file the agent created', () {
      write('keep.dart', 'was here before');
      final entry = record('draft.dart', after: 'agent made this');

      final report = rewind(entry.id);

      expect(report.deleted, ['draft.dart']);
      expect(exists('draft.dart'), isFalse);
      expect(read('keep.dart'), 'was here before');
    });

    test('a created file that is already gone is reported as nothing', () {
      final entry = record('draft.dart', after: 'agent made this');
      File(workspace.resolve('draft.dart')).deleteSync();

      final report = rewind(entry.id);

      // Nothing was removed and nothing was blocked: promising a delete that did
      // not happen would be a report the user cannot trust.
      expect(report.didNothing, isTrue);
    });

    test('goes back to the first write in range, not the last one', () {
      final first = record('a.dart', before: 'original', after: 'v1');
      record('a.dart', before: 'v1', after: 'v2');
      record('a.dart', before: 'v2', after: 'v3');
      expect(read('a.dart'), 'v3');

      final report = rewind(first.id);

      expect(report.restored, ['a.dart']);
      expect(read('a.dart'), 'original');
    });

    test('refuses when the file is no longer what the agent left', () {
      final entry = record('a.dart', before: 'mine', after: 'agent version');
      write('a.dart', 'the user fixed it themselves');

      final report = rewind(entry.id);

      expect(report.restored, isEmpty);
      expect(
        report.skipped.single.reason,
        RewindSkipReason.changedOutsideAgent,
      );
      expect(read('a.dart'), 'the user fixed it themselves');
    });

    test('refuses to delete a created file the user has since edited', () {
      final entry = record('draft.dart', after: 'agent made this');
      write('draft.dart', 'and I kept working on it');

      final report = rewind(entry.id);

      expect(report.deleted, isEmpty);
      expect(
        report.skipped.single.reason,
        RewindSkipReason.changedOutsideAgent,
      );
      expect(read('draft.dart'), 'and I kept working on it');
    });

    test('the preview agrees with the action, block included', () {
      final first = record('a.dart', before: 'mine', after: 'agent version');
      record('b.dart', before: 'yours', after: 'agent version');
      write('b.dart', 'user edit');

      final shown = preview(first.id);
      expect(shown.map((file) => file.path), ['a.dart', 'b.dart']);
      expect(shown.first.blocked, isFalse);
      expect(shown.last.blocked, isTrue);
      // The reason travels with the row: the confirmation is what the user
      // judges, and "not going back" without "why" is not judgeable.
      expect(shown.last.blockedBy, RewindSkipReason.changedOutsideAgent);

      final report = rewind(first.id);
      expect(report.restored, ['a.dart']);
      expect(report.skipped.map((skip) => skip.path), ['b.dart']);
      expect(read('a.dart'), 'mine');
      expect(read('b.dart'), 'user edit');
    });

    test('names the files it would delete before deleting them', () {
      final entry = record('draft.dart', after: 'agent made this');

      final shown = preview(entry.id);

      expect(shown.single.deletes, isTrue);
      expect(shown.single.blocked, isFalse);
      expect(exists('draft.dart'), isTrue);
    });

    test('a conversation scope stops at its own files', () {
      final mine = record('a.dart', before: 'mine', after: 'v1');
      store.conversation = 'other';
      record('b.dart', before: 'theirs', after: 'v1');
      store.conversation = conv;

      final report = rewind(mine.id);

      expect(report.restored, ['a.dart']);
      expect(read('a.dart'), 'mine');
      // Out of scope, so untouched: the other conversation's write stands.
      expect(read('b.dart'), 'v1');
    });

    test(
      'a write by another conversation on the same path blocks the rewind',
      () {
        final mine = record('a.dart', before: 'mine', after: 'v1');
        store.conversation = 'other';
        record('a.dart', before: 'v1', after: 'theirs');
        store.conversation = conv;

        final report = rewind(mine.id);

        // Not in this conversation's range, but it is what is on disk now, and the
        // guard compares against the disk: restoring would silently discard the
        // other conversation's work, so the rewind declines instead.
        expect(report.restored, isEmpty);
        expect(
          report.skipped.single.reason,
          RewindSkipReason.changedOutsideAgent,
        );
        expect(read('a.dart'), 'theirs');
      },
    );

    test('a workspace scope reaches every conversation in the folder', () {
      final first = record('a.dart', before: 'mine', after: 'v1');
      store.conversation = 'other';
      record('b.dart', before: 'theirs', after: 'v1');
      store.conversation = conv;

      final report = rewind(first.id, scope: RewindScope.workspace);

      expect(report.restored, ['a.dart', 'b.dart']);
      expect(read('a.dart'), 'mine');
      expect(read('b.dart'), 'theirs');
    });

    test('an id or a conversation nobody recorded rewinds nothing', () {
      final entry = record('a.dart', before: 'mine', after: 'v1');

      expect(rewind('${entry.id}-nope').didNothing, isTrue);
      expect(
        rewind(entry.id, conversation: 'another-session').didNothing,
        isTrue,
      );
      expect(read('a.dart'), 'v1');
    });
  });

  group('conversation identity and budget', () {
    test('the placeholder becomes the session id once one exists', () {
      final entry = record('a.dart', before: 'mine', after: 'v1');
      expect(entry.conversation, conv);

      store.adoptConversation(conv, 'sess-9');
      expect(entry.conversation, 'sess-9');

      final reopened = CheckpointStore.open(support);
      addTearDown(reopened.dispose);
      reopened.useWorkspace(root.path);
      expect(reopened.savedFor(root.path).single.conversation, 'sess-9');
    });

    test('past the budget entries go, and a surviving undo still works', () {
      final tight = CheckpointStore.open(support, maxTotalBytes: 30);
      addTearDown(tight.dispose);
      tight
        ..useWorkspace(root.path)
        ..conversation = conv;
      for (var i = 0; i < 8; i++) {
        record(
          'f$i.dart',
          before: 'before-image-$i',
          after: 'after-$i',
          into: tight,
        );
      }

      final kept = tight.savedFor(root.path);
      expect(kept.length, lessThan(8));
      // The invariant is not *which* entries go — the clock can tie — but that
      // pruning never breaks an undo it left behind.
      for (final entry in kept) {
        expect(
          File(blobPath(entry.beforeFingerprint!)).existsSync(),
          isTrue,
          reason: entry.id,
        );
      }

      final last = kept.last;
      final report = tight.rewindTo(
        id: last.id,
        workspace: workspace,
        conversation: conv,
      );
      expect(report.restored, [last.path]);
      expect(
        read(last.path),
        'before-image-${last.path.substring(1, last.path.length - '.dart'.length)}',
      );
    });
  });
}
