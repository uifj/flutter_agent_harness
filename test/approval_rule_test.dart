// The sentence this file holds: a rule speaks for exactly the subject the user
// was shown, deny always wins, and one subject has one decision.
//
// The approval rules are the only place in the app where a saved answer replaces
// a human decision, so the matching is pinned here rather than trusted: what it
// matches, in what priority, and what survives a round trip through the file.

import 'package:agent_harness/model/approval_rule.dart';
import 'package:agent_harness/model/conversation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('matching', () {
    test('an exact subject matches and anything else does not', () {
      final rule = ApprovalRule(
        kind: ApprovalSubjectKind.command,
        value: 'git status',
        outcome: ApprovalOutcome.allow,
      );
      expect(rule.matches(ApprovalSubjectKind.command, 'git status'), isTrue);
      expect(
        rule.matches(ApprovalSubjectKind.command, 'git status -s'),
        isFalse,
      );
      // A command rule says nothing about a file of the same name.
      expect(rule.matches(ApprovalSubjectKind.filePath, 'git status'), isFalse);
    });

    test('a trailing wildcard is a prefix', () {
      const rule = ApprovalRule(
        kind: ApprovalSubjectKind.command,
        value: 'dart format *',
        outcome: ApprovalOutcome.allow,
      );
      expect(
        rule.matches(ApprovalSubjectKind.command, 'dart format lib'),
        isTrue,
      );
      expect(
        rule.matches(ApprovalSubjectKind.command, 'cat dart format '),
        isFalse,
      );
    });

    test('a wildcard anywhere but the end is literal', () {
      // `* install` would read as "anything containing install", which is the
      // one shape that turns an approval rule into a rubber stamp.
      final rule = ApprovalRule(
        kind: ApprovalSubjectKind.command,
        value: '* install',
        outcome: ApprovalOutcome.allow,
      );
      expect(rule.matches(ApprovalSubjectKind.command, '* install'), isTrue);
      expect(
        rule.matches(ApprovalSubjectKind.command, 'brew install'),
        isFalse,
      );
    });
  });

  group('the book', () {
    const file = ApprovalSubjectKind.filePath;

    test('a deny wins over an allow for the same subject', () {
      final book = ApprovalRuleBook(
        rules: const [
          ApprovalRule(
            kind: file,
            value: 'secrets.env',
            outcome: ApprovalOutcome.allow,
          ),
          ApprovalRule(
            kind: file,
            value: 'secre*',
            outcome: ApprovalOutcome.deny,
          ),
        ],
      );
      expect(book.decide(file, 'secrets.env'), ApprovalOutcome.deny);
    });

    test('nothing matched is no verdict, which means ask', () {
      final book = ApprovalRuleBook(
        rules: const [
          ApprovalRule(
            kind: file,
            value: 'lib/*.dart',
            outcome: ApprovalOutcome.allow,
          ),
        ],
      );
      expect(book.decide(file, 'pubspec.yaml'), isNull);
    });

    test('a second decision about a subject replaces the first', () {
      final book = ApprovalRuleBook();
      book.add(
        const ApprovalRule(
          kind: file,
          value: 'a.txt',
          outcome: ApprovalOutcome.allow,
        ),
      );
      book.add(
        const ApprovalRule(
          kind: file,
          value: 'a.txt',
          outcome: ApprovalOutcome.deny,
        ),
      );
      expect(book.rules, hasLength(1));
      expect(book.decide(file, 'a.txt'), ApprovalOutcome.deny);
    });

    test("another folder's rules are not inherited", () {
      final book = ApprovalRuleBook(
        rules: const [
          ApprovalRule(
            kind: file,
            value: 'a.txt',
            outcome: ApprovalOutcome.allow,
          ),
        ],
      );
      book.load(const []);
      expect(book.decide(file, 'a.txt'), isNull);
    });
  });

  group('the file format', () {
    test('a rule survives the round trip', () {
      const rule = ApprovalRule(
        kind: ApprovalSubjectKind.tool,
        value: 'weather/forecast',
        outcome: ApprovalOutcome.allow,
      );
      expect(ApprovalRule.fromJson(rule.toJson()), rule);
    });

    test('an unknown subject kind is refused, not guessed', () {
      expect(
        () => ApprovalRule.fromJson({'kind': 'socket', 'value': 'x'}),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => ApprovalRule.fromJson({'kind': 'command', 'value': ''}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('what the panel can remember', () {
    ApprovalRequest asked({
      required Map<String, dynamic> details,
      Map<String, dynamic> arguments = const {},
    }) => ApprovalRequest(
      ref: 'r1',
      toolName: 'x',
      arguments: arguments,
      details: details,
    );

    test('bash remembers the command it showed', () {
      final rule = asked(
        details: const {'kind': 'bash', 'command': 'git push'},
      ).ruleFor(ApprovalOutcome.allow);
      expect(rule?.kind, ApprovalSubjectKind.command);
      expect(rule?.value, 'git push');
    });

    test('a write remembers the relative path it showed', () {
      final rule = asked(
        details: const {'kind': 'write', 'path': 'lib/a.dart'},
      ).ruleFor(ApprovalOutcome.allow);
      expect(rule?.kind, ApprovalSubjectKind.filePath);
      expect(rule?.value, 'lib/a.dart');
    });

    test('an external tool remembers server/tool', () {
      final rule = asked(
        details: const {'kind': 'mcp', 'server': 'weather', 'tool': 'forecast'},
      ).ruleFor(ApprovalOutcome.allow);
      expect(rule?.value, 'weather/forecast');
    });

    test('the arguments are the fallback when the payload is thin', () {
      final rule = asked(
        details: const {'kind': 'edit'},
        arguments: const {'file_path': 'lib/b.dart'},
      ).ruleFor(ApprovalOutcome.allow);
      expect(rule?.value, 'lib/b.dart');
    });

    test('a call with no named subject has nothing to remember', () {
      expect(
        asked(details: const {'kind': 'plan'}).ruleFor(ApprovalOutcome.allow),
        isNull,
      );
      expect(
        asked(details: const {'kind': 'bash'}).ruleFor(ApprovalOutcome.allow),
        isNull,
      );
    });
  });
}
