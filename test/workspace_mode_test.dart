// The one sentence this file holds: the 企划/代理 switch resets the plan
// extension panel on the starkins schedule — leaving plan closes it, entering
// plan starts at the document view — and the extension rows are their own
// toggles.
//
// This is the ADR-0007 S2 guard. The controller is pure view state (nothing
// persisted), so what matters is exactly the reset semantics the UI relies on.

import 'package:agent_harness/state/workspace_mode_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late WorkspaceModeController controller;

  setUp(() {
    controller = WorkspaceModeController();
  });

  tearDown(() => controller.dispose());

  test('a fresh controller sits in the agent workspace', () {
    expect(controller.mode, WorkspaceMode.agent);
    expect(controller.extensionView, PlanExtensionView.none);
  });

  test('switching to plan starts at the document view', () {
    controller.selectMode(WorkspaceMode.plan);
    expect(controller.mode, WorkspaceMode.plan);
    expect(controller.extensionView, PlanExtensionView.none);
  });

  test('leaving plan closes its extension panel', () {
    controller
      ..selectMode(WorkspaceMode.plan)
      ..toggleExtension(PlanExtensionView.board);
    expect(controller.extensionView, PlanExtensionView.board);

    controller.selectMode(WorkspaceMode.agent);
    expect(controller.mode, WorkspaceMode.agent);
    expect(controller.extensionView, PlanExtensionView.none);
  });

  test('an extension row toggles: open once, close again', () {
    controller.toggleExtension(PlanExtensionView.calendar);
    expect(controller.mode, WorkspaceMode.plan);
    expect(controller.extensionView, PlanExtensionView.calendar);

    controller.toggleExtension(PlanExtensionView.calendar);
    expect(controller.mode, WorkspaceMode.plan);
    expect(controller.extensionView, PlanExtensionView.none);
  });

  test('opening an extension from the agent workspace enters plan', () {
    controller.toggleExtension(PlanExtensionView.table);
    expect(controller.mode, WorkspaceMode.plan);
    expect(controller.extensionView, PlanExtensionView.table);
  });

  test('listeners fire only on real changes', () {
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.selectMode(WorkspaceMode.agent); // no-op: same mode, no panel
    expect(notifications, 0);

    controller.selectMode(WorkspaceMode.plan); // real switch
    expect(notifications, 1);

    controller.selectMode(WorkspaceMode.plan); // no-op again
    expect(notifications, 1);
  });
}
