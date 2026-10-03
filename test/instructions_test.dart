// The sentence this file holds: instruction discovery is precedence, escape
// rejection and budget — nothing else.
//
// These run against a real temp tree because all three properties are
// filesystem facts: symlink resolution, canonical paths and UTF-8 byte length
// are exactly the things a fake would assert about itself instead of about the
// disk. Paths are canonicalised up front so a macOS temp dir (`/var` sitting
// behind a symlink) compares equal to itself.

import 'dart:convert';
import 'dart:io';

import 'package:planstar/genkit/instructions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late String home;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('instructions_');
    home = p.canonicalize(temp.path);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  String workspace(String name) {
    final dir = Directory(p.join(temp.path, name))..createSync(recursive: true);
    return p.canonicalize(dir.path);
  }

  void write(String path, String text) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  }

  List<InstructionFile> discover(String? repo) =>
      discoverInstructions(workspaceRoot: repo, homeRoot: home);

  test('the user file comes first and the workspace file is read last', () {
    write(p.join(userInstructionRoot(home), 'AGENTS.md'), 'user rule');
    final repo = workspace('repo');
    write(p.join(repo, 'AGENTS.md'), 'repo rule');
    write(p.join(repo, 'sub', 'AGENTS.md'), 'sub rule');

    final found = discover(repo);

    expect(found.map((file) => file.text).toList(), ['user rule', 'repo rule']);
    expect(found.first.origin, InstructionOrigin.user);
    expect(found.last.origin, InstructionOrigin.project);
    // Discovery is upward from the workspace, never downward: a nested
    // directory's own AGENTS.md is the model's `read` tool to find, not
    // something to hoist into every prompt.
    expect(found.any((file) => file.text == 'sub rule'), isFalse);
  });

  test('.agents/AGENTS.md is recognised beside AGENTS.md', () {
    final repo = workspace('repo');
    write(p.join(repo, '.agents', 'AGENTS.md'), 'dot agents rule');

    expect(discover(repo).map((file) => file.text).toList(), [
      'dot agents rule',
    ]);
  });

  test('with no workspace open, only the user-level file is offered', () {
    write(p.join(userInstructionRoot(home), 'AGENTS.md'), 'user rule');

    expect(discover(null).map((file) => file.origin).toList(), [
      InstructionOrigin.user,
    ]);
  });

  test('a workspace that contains the user file does not read it twice', () {
    final root = workspace('home');
    write(p.join(userInstructionRoot(root), 'AGENTS.md'), 'once');
    write(p.join(root, 'AGENTS.md'), 'twice');

    final found = discoverInstructions(workspaceRoot: root, homeRoot: root);

    expect(found.map((file) => file.path).toSet().length, found.length);
    expect(found.map((file) => file.text).toList(), ['once', 'twice']);
  });

  test('a symlink that escapes the workspace is skipped', () {
    final repo = workspace('repo');
    final outside = workspace('outside');
    write(p.join(outside, 'SECRET.md'), 'not yours');
    Link(p.join(repo, 'AGENTS.md')).createSync(p.join(outside, 'SECRET.md'));

    expect(discover(repo), isEmpty);
  });

  test('a file reached through a symlinked directory is still read', () {
    final repo = workspace('repo');
    final shared = workspace('shared');
    write(p.join(shared, 'AGENTS.md'), 'shared rules');
    Link(p.join(repo, 'nested')).createSync(shared, recursive: true);

    expect(discover(p.join(repo, 'nested')).map((file) => file.text).toList(), [
      'shared rules',
    ]);
  });

  test('an oversized file is cut on a code-point boundary and says so', () {
    final repo = workspace('repo');
    write(p.join(repo, 'AGENTS.md'), '字' * (perFileByteCap ~/ 3 + 200));

    final found = discover(repo);

    expect(found.single.truncated, isTrue);
    expect(
      utf8.encode(found.single.text).length,
      lessThanOrEqualTo(perFileByteCap),
    );
    expect(found.single.text.runes.every((rune) => rune == 0x5b57), isTrue);
  });

  test('ancestor directories above the workspace join the chain', () {
    // The upward search is the whole point of it: a shared file one level above
    // a project applies to it. Rejected inside the workspace, trusted outside.
    final deep = workspace(p.join('proj', 'pkg'));
    write(p.join(temp.path, 'proj', 'AGENTS.md'), 'shared across projects');
    write(p.join(deep, 'AGENTS.md'), 'pkg rule');

    expect(discover(deep).map((file) => file.text).toList(), [
      'shared across projects',
      'pkg rule',
    ]);
  });

  test('the total budget stops the chain instead of overflowing it', () {
    // Four near-cap files fit in sequence and the fifth is never opened: the
    // budget is spent, so the walk stops rather than pushing context at the
    // provider until it refuses the request.
    final deep = workspace(p.join('a', 'b', 'c', 'd', 'e'));
    final big = 'a' * (perFileByteCap - 16);
    write(p.join(temp.path, 'a', 'AGENTS.md'), big);
    write(p.join(temp.path, 'a', 'b', 'AGENTS.md'), big);
    write(p.join(temp.path, 'a', 'b', 'c', 'AGENTS.md'), big);
    write(p.join(temp.path, 'a', 'b', 'c', 'd', 'AGENTS.md'), big);
    write(
      p.join(temp.path, 'a', 'b', 'c', 'd', 'e', 'AGENTS.md'),
      'never read',
    );

    final found = discover(deep);

    // Three whole files plus the remainder of a fourth, and no fifth.
    expect(found.length, 4);
    expect(found.last.truncated, isTrue);
    expect(utf8.encode(found.last.text).length, lessThan(perFileByteCap));
    expect(
      utf8.encode(found.map((file) => file.text).join()).length,
      lessThanOrEqualTo(totalByteCap),
    );
    expect(found.any((file) => file.text == 'never read'), isFalse);
  });

  test('an unknown home folder still yields the workspace chain', () {
    final repo = workspace('repo');
    write(p.join(repo, 'AGENTS.md'), 'repo rule');

    final found = discoverInstructions(workspaceRoot: repo, homeRoot: null);

    expect(found.map((file) => file.origin).toList(), [
      InstructionOrigin.project,
    ]);
  });

  test('the rendered block names every file, and empty input renders null', () {
    expect(renderInstructions(const []), isNull);

    final repo = workspace('repo');
    write(p.join(repo, 'AGENTS.md'), 'keep it small');
    final block = renderInstructions(discover(repo));

    expect(block, startsWith('<project-instructions>'));
    expect(block, contains('AGENTS.md'));
    expect(block, contains('keep it small'));
    expect(block, endsWith('</project-instructions>'));
  });
}
