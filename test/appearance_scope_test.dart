// The one sentence this file holds: the conversation width and a tool call's
// starting expansion reach the tree through `AppearanceScope`, and — crucially —
// a tree WITHOUT the scope falls back to the pre-ADR-0005 defaults.
//
// The fallback is what keeps the whole existing suite honest: `chat_view_test`,
// `composer_test`, and `details_panel_test` all pump their widgets without
// mounting the scope, and they must keep measuring 748px and collapsed tool
// rows exactly as before. The real app always mounts the scope (in `main`), so
// it never sees the fallback; the live widen / auto-expand wiring is verified on
// device at ADR-0005 S5.

import 'package:agent_harness/ui/appearance_scope.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('absent a scope, the resolved values are the legacy defaults', (
    tester,
  ) async {
    double? width;
    bool? expand;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          width = AppearanceScope.widthOf(context, 748);
          expand = AppearanceScope.expandToolCallsOf(context);
          return const SizedBox.shrink();
        },
      ),
    );
    expect(width, 748);
    expect(expand, isFalse);
  });

  testWidgets('a mounted scope overrides both reads', (tester) async {
    double? width;
    bool? expand;
    await tester.pumpWidget(
      AppearanceScope(
        contentWidth: 960,
        expandToolCalls: true,
        child: Builder(
          builder: (context) {
            width = AppearanceScope.widthOf(context, 748);
            expand = AppearanceScope.expandToolCallsOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(width, 960);
    expect(expand, isTrue);
  });
}
