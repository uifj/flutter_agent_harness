// The sentence this file holds: a saved approval belongs to the folder it was
// given in, and the file is the only memory between launches.
//
// Run against a real temp directory because the two things worth proving are
// filesystem facts — that the rename lands, and that a reopened store reads
// what the previous one wrote. A fake could assert neither.

import 'dart:convert';
import 'dart:io';

import 'package:planstar/model/approval_rule.dart';
import 'package:planstar/state/approval_rule_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;
  const oneFolder = '/work/alpha';
  const otherFolder = '/work/beta';
  const rule = ApprovalRule(
    kind: ApprovalSubjectKind.command,
    value: 'git status',
    outcome: ApprovalOutcome.allow,
  );

  setUp(() => root = Directory.systemTemp.createTempSync('approvals_'));
  tearDown(() => root.deleteSync(recursive: true));

  ApprovalRuleStore opened() => ApprovalRuleStore.open(root);

  test('an empty folder has no rules and no file', () {
    final store = opened();
    expect(store.savedFor(oneFolder), isEmpty);
    expect(File(p.join(root.path, 'approvals.json')).existsSync(), isFalse);
  });

  test('a remembered rule is read back by a new store', () async {
    final store = opened()..useWorkspace(oneFolder);
    await store.remember(rule);

    // The live book answers the gate, the reopened one proves the write.
    expect(store.book.decide(rule.kind, rule.value), ApprovalOutcome.allow);
    expect(opened().savedFor(oneFolder), [rule]);
  });

  test('another folder does not get the decision', () async {
    final store = opened()..useWorkspace(oneFolder);
    await store.remember(rule);

    expect(store.savedFor(otherFolder), isEmpty);
    store.useWorkspace(otherFolder);
    expect(store.book.decide(rule.kind, rule.value), isNull);
  });

  test('switching back brings the rules with it', () async {
    final store = opened()..useWorkspace(oneFolder);
    await store.remember(rule);
    store.useWorkspace(otherFolder);
    store.useWorkspace(oneFolder);
    expect(store.book.decide(rule.kind, rule.value), ApprovalOutcome.allow);
  });

  test('forgetting writes the empty list away', () async {
    final store = opened()..useWorkspace(oneFolder);
    await store.remember(rule);
    await store.forget(rule);

    expect(store.book.rules, isEmpty);
    expect(opened().savedFor(oneFolder), isEmpty);
  });

  test('forgetWorkspace clears only that folder', () async {
    final store = opened()..useWorkspace(oneFolder);
    await store.remember(rule);
    store.useWorkspace(otherFolder);
    await store.remember(
      const ApprovalRule(
        kind: ApprovalSubjectKind.filePath,
        value: 'a.txt',
        outcome: ApprovalOutcome.allow,
      ),
    );

    await store.forgetWorkspace(oneFolder);

    expect(opened().savedFor(oneFolder), isEmpty);
    expect(opened().savedFor(otherFolder), hasLength(1));
  });

  test('no workspace open still keeps its own bucket', () async {
    final store = opened()..useWorkspace(null);
    await store.remember(rule);
    expect(opened().savedFor(null), [rule]);
  });

  test('a corrupt document is absent, not half-read', () {
    File(p.join(root.path, 'approvals.json')).writeAsStringSync('{not json');
    final store = opened();
    expect(store.book.rules, isEmpty);
    expect(store.savedFor(oneFolder), isEmpty);
  });

  test('one malformed row drops without taking the rest with it', () {
    File(p.join(root.path, 'approvals.json')).writeAsStringSync(
      jsonEncode({
        oneFolder: [
          {'kind': 'socket', 'value': 'guessed'},
          {'kind': 'command', 'value': ''},
          rule.toJson(),
        ],
      }),
    );

    final store = opened()..useWorkspace(oneFolder);

    expect(store.book.rules, [rule]);
  });

  test('the write is atomic: a tmp file never outlives it', () async {
    final store = opened()..useWorkspace(oneFolder);
    await store.remember(rule);
    expect(File(p.join(root.path, 'approvals.json.tmp')).existsSync(), isFalse);
  });
}
