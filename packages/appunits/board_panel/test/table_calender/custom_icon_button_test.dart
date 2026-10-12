// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:board_panel/src/widgets/table_calendar/custom_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Widget setupTestWidget(Widget child) {
  return ShadTheme(
    data: ShadThemeData(
      colorScheme: const ShadSlateColorScheme.light(),
      brightness: Brightness.light,
    ),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Material(child: child),
    ),
  );
}

void main() {
  testWidgets('onTap gets called when CustomIconButton is tapped', (
    tester,
  ) async {
    bool buttonTapped = false;

    await tester.pumpWidget(
      setupTestWidget(
        CustomIconButton(
          icon: const Icon(Icons.chevron_left),
          onTap: () {
            buttonTapped = true;
          },
        ),
      ),
    );

    final button = find.byType(CustomIconButton);
    expect(button, findsOneWidget);
    expect(buttonTapped, false);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(buttonTapped, true);
  });
}
