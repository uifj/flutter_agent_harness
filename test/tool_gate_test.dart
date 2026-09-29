// The sentence this file holds: the gate's order is plan → standing deny →
// standing allow → mode, and there is exactly one such order.
//
// `decideGate` is the policy the three writable tools and the external-tool
// middleware share (ADR-0012). It is asserted here rather than through a live
// turn because a live turn needs an API key: what is worth pinning is which of
// the four inputs wins, and that is a pure decision.

import 'package:agent_harness/genkit/tools.dart';
import 'package:agent_harness/model/approval_mode.dart';
import 'package:agent_harness/model/approval_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const subject = 'lib/main.dart';
  const planRefusal = {'ok': false, 'error': 'Plan mode is on.'};

  GateDecision run(
    ApprovalMode mode, {
    ApprovalOutcome? decided,
    Map<String, dynamic>? modeRefusal,
  }) => decideGate(
    mode: mode,
    subject: subject,
    decided: decided,
    modeRefusal: modeRefusal,
  );

  group('ask', () {
    test('nothing decided interrupts', () {
      expect(run(ApprovalMode.ask).outcome, GateOutcome.ask);
    });

    test('an allow rule answers unheard', () {
      expect(
        run(ApprovalMode.ask, decided: ApprovalOutcome.allow).outcome,
        GateOutcome.proceed,
      );
    });

    test('a deny rule answers with a reason the model reads', () {
      final decision = run(ApprovalMode.ask, decided: ApprovalOutcome.deny);
      expect(decision.outcome, GateOutcome.refused);
      expect(
        decision.refusal!['error'],
        stringContainsInOrder(['standing rule', subject]),
      );
    });
  });

  test('plan refuses even when a rule would have allowed', () {
    // The mode is the harder boundary: plan means "change nothing until the
    // plan is approved", and a leftover allow rule must not quietly reopen it.
    final decision = run(
      ApprovalMode.plan,
      decided: ApprovalOutcome.allow,
      modeRefusal: planRefusal,
    );
    expect(decision.outcome, GateOutcome.refused);
    expect(decision.refusal, planRefusal);
  });

  test('auto runs without asking, but a standing deny still stops it', () {
    expect(
      run(ApprovalMode.auto).outcome,
      GateOutcome.proceed,
      reason: 'auto means no prompt',
    );
    expect(
      run(ApprovalMode.auto, decided: ApprovalOutcome.deny).outcome,
      GateOutcome.refused,
      reason: '"never" outranks "do not ask me"',
    );
  });

  group('the read-only declaration', () {
    test('names the tools the delegation target may use', () {
      expect(WorkspaceTools.isReadOnly('read'), isTrue);
      expect(WorkspaceTools.isReadOnly('glob'), isTrue);
      expect(WorkspaceTools.isReadOnly('grep'), isTrue);
      // The writable three must never reach a sub-agent: its interrupt cannot
      // get to the UI, so it would hang on a question nobody can answer.
      for (final name in ['write', 'edit', 'bash']) {
        expect(WorkspaceTools.isReadOnly(name), isFalse, reason: name);
      }
    });
  });
}
