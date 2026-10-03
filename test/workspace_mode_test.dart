// The one sentence this file holds: the 企划/代理 switch resets the plan
// collection panel on the starkins schedule — leaving plan closes it, entering
// plan starts at the document view — and the collection rows are their own
// toggles.
//
// The ADR-0007 S2 guard, carried over to the ADR-0037 shape: the old
// hard-coded extension panels (board / calendar / table) retired on
// 2026-10-01, and the extension area lists plan collections, so the panel
// state is one collection id. The controller is pure view state (nothing
// persisted), so what matters is exactly the reset semantics the UI relies on.

import 'package:planstar/state/workspace_mode_controller.dart';
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

  test('leaving plan closes its collection panel', () {
    controller
      ..selectMode(WorkspaceMode.plan)
      ..openCollection('set-tasks');
    expect(controller.extensionView, PlanExtensionView.collection);
    expect(controller.openCollectionId, 'set-tasks');

    controller.selectMode(WorkspaceMode.agent);
    expect(controller.mode, WorkspaceMode.agent);
    expect(controller.extensionView, PlanExtensionView.none);
  });

  test('a collection row toggles: open once, close again', () {
    controller.openCollection('set-tasks');
    expect(controller.mode, WorkspaceMode.plan);
    expect(controller.extensionView, PlanExtensionView.collection);
    expect(controller.openCollectionId, 'set-tasks');

    controller.openCollection('set-tasks');
    expect(controller.extensionView, PlanExtensionView.none);
    expect(controller.openCollectionId, isNull);
  });

  test('opening a collection from the agent workspace enters plan', () {
    controller.openCollection('col-inbox');
    expect(controller.mode, WorkspaceMode.plan);
    expect(controller.extensionView, PlanExtensionView.collection);
  });

  test('switching collections keeps the panel up and moves the id', () {
    controller
      ..selectMode(WorkspaceMode.plan)
      ..openCollection('set-tasks')
      ..openCollection('col-inbox');
    expect(controller.extensionView, PlanExtensionView.collection);
    expect(controller.openCollectionId, 'col-inbox');
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
