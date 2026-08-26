// The workspace escape guard. This is the only security boundary in the app, so
// it gets tested directly rather than through a tool call.

import 'dart:io';

import 'package:agent_harness/model/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late Directory rootDir;
  late Directory outsideDir;
  late Workspace workspace;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dsh_workspace_test_');
    rootDir = Directory(p.join(temp.path, 'root'))..createSync();
    outsideDir = Directory(p.join(temp.path, 'outside'))..createSync();
    File(p.join(rootDir.path, 'inside.txt')).writeAsStringSync('in');
    File(p.join(outsideDir.path, 'secret.txt')).writeAsStringSync('out');
    workspace = Workspace.of(rootDir.path);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  group('accepts', () {
    test('a relative path', () {
      expect(
        workspace.resolve('inside.txt'),
        p.join(workspace.root, 'inside.txt'),
      );
    });

    test('an absolute path inside the root', () {
      expect(
        workspace.resolve(p.join(rootDir.path, 'inside.txt')),
        p.join(workspace.root, 'inside.txt'),
      );
    });

    test('the root itself', () {
      expect(workspace.resolve('.'), workspace.root);
    });

    test('a nested path that does not exist yet', () {
      // write has to be able to name a file before creating it.
      expect(
        workspace.resolve('new/deeper/file.txt'),
        p.join(workspace.root, 'new', 'deeper', 'file.txt'),
      );
    });

    test('a traversal that stays inside', () {
      expect(
        workspace.resolve('sub/../inside.txt'),
        p.join(workspace.root, 'inside.txt'),
      );
    });
  });

  group('refuses', () {
    test('a relative traversal out of the root', () {
      expect(
        () => workspace.resolve('../outside/secret.txt'),
        throwsA(isA<WorkspaceDenied>()),
      );
    });

    test('an absolute path outside the root', () {
      expect(
        () => workspace.resolve(p.join(outsideDir.path, 'secret.txt')),
        throwsA(isA<WorkspaceDenied>()),
      );
    });

    test('an empty path', () {
      expect(() => workspace.resolve('   '), throwsA(isA<WorkspaceDenied>()));
    });

    test('a path that does not exist outside the root', () {
      expect(
        () => workspace.resolve('../outside/nope.txt'),
        throwsA(isA<WorkspaceDenied>()),
      );
    });

    test('a symlinked file pointing out of the root', () {
      // A plain prefix comparison would let this through: the path really does
      // start with the root.
      Link(
        p.join(rootDir.path, 'link.txt'),
      ).createSync(p.join(outsideDir.path, 'secret.txt'));
      expect(
        () => workspace.resolve('link.txt'),
        throwsA(isA<WorkspaceDenied>()),
      );
    });

    test('a file under a symlinked directory pointing out of the root', () {
      Link(p.join(rootDir.path, 'escape')).createSync(outsideDir.path);
      expect(
        () => workspace.resolve('escape/secret.txt'),
        throwsA(isA<WorkspaceDenied>()),
      );
    });

    test('a file that does not exist under a symlinked directory', () {
      // The parent chain is what carries the escape, so the guard has to resolve
      // it even when the leaf is absent.
      Link(p.join(rootDir.path, 'escape')).createSync(outsideDir.path);
      expect(
        () => workspace.resolve('escape/brand-new.txt'),
        throwsA(isA<WorkspaceDenied>()),
      );
    });
  });

  test('canonicalises the root once, so comparisons are against a real path', () {
    // On macOS the temp directory itself lives behind a /var -> /private/var
    // symlink, so an uncanonicalised root would fail every `isWithin` check.
    expect(workspace.root, Directory(rootDir.path).resolveSymbolicLinksSync());
    expect(p.isAbsolute(workspace.root), isTrue);
  });
}
