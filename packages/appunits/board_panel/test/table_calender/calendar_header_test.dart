// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:board_panel/src/customization/header_style.dart';
import 'package:board_panel/src/utils/utils.dart';
import 'package:board_panel/src/widgets/table_calendar/calendar_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'common.dart';

Widget _wrapWithShadTheme(Widget child) {
  return ShadTheme(
    data: ShadThemeData(
      colorScheme: const ShadSlateColorScheme.light(),
      brightness: Brightness.light,
    ),
    child: child,
  );
}

final focusedMonth = DateTime.utc(2021, 7, 15);

Widget setupTestWidget({
  HeaderStyle headerStyle = const HeaderStyle(),
  VoidCallback? onLeftChevronTap,
  VoidCallback? onRightChevronTap,
  VoidCallback? onHeaderTap,
  VoidCallback? onHeaderLongPress,
  void Function(CalendarFormat)? onFormatButtonTap,
  Map<CalendarFormat, String> availableCalendarFormats = calendarFormatMap,
}) {
  return _wrapWithShadTheme(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: CalendarHeader(
          focusedMonth: focusedMonth,
          calendarFormat: CalendarFormat.month,
          headerStyle: headerStyle,
          onLeftChevronTap: () => onLeftChevronTap?.call(),
          onRightChevronTap: () => onRightChevronTap?.call(),
          onHeaderTap: () => onHeaderTap?.call(),
          onHeaderLongPress: () => onHeaderLongPress?.call(),
          onFormatButtonTap: (format) => onFormatButtonTap?.call(format),
          availableCalendarFormats: availableCalendarFormats,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Displays corrent month and year for given focusedMonth', (
    tester,
  ) async {
    await tester.pumpWidget(setupTestWidget());

    final headerText = intl.DateFormat.yMMMM().format(focusedMonth);

    expect(find.byType(CalendarHeader), findsOneWidget);
    expect(find.text(headerText), findsOneWidget);
  });
  testWidgets(
    'Ensure chevrons and FormatButton are visible by default, test onTap callbacks',
    (tester) async {
      bool leftChevronTapped = false;
      bool rightChevronTapped = false;
      bool headerTapped = false;
      bool headerLongPressed = false;
      bool formatButtonTapped = false;

      await tester.pumpWidget(
        setupTestWidget(
          onLeftChevronTap: () => leftChevronTapped = true,
          onRightChevronTap: () => rightChevronTapped = true,
          onHeaderTap: () => headerTapped = true,
          onHeaderLongPress: () => headerLongPressed = true,
          onFormatButtonTap: (_) => formatButtonTapped = true,
        ),
      );

      final leftChevron = find.widgetWithIcon(
        ShadIconButton,
        Icons.chevron_left,
      );

      final rightChevron = find.widgetWithIcon(
        ShadIconButton,
        Icons.chevron_right,
      );

      final header = find.byType(CalendarHeader);
      final formatButton = find.widgetWithText(ShadButton, '2 weeks');

      expect(leftChevron, findsOneWidget);
      expect(rightChevron, findsOneWidget);
      expect(header, findsOneWidget);
      expect(formatButton, findsOneWidget);

      expect(leftChevronTapped, false);
      expect(rightChevronTapped, false);
      expect(headerTapped, false);
      expect(headerLongPressed, false);
      expect(formatButtonTapped, false);

      await tester.tap(leftChevron);
      await tester.pumpAndSettle();

      await tester.tap(rightChevron);
      await tester.pumpAndSettle();

      await tester.tap(header);
      await tester.pumpAndSettle();

      await tester.longPress(header);
      await tester.pumpAndSettle();

      await tester.tap(formatButton);
      await tester.pumpAndSettle();

      expect(leftChevronTapped, true);
      expect(rightChevronTapped, true);
      expect(headerTapped, true);
      expect(headerLongPressed, true);
      expect(formatButtonTapped, true);
    },
  );

  testWidgets(
    'When leftChevronVisible is false, do not show the left chevron',
    (tester) async {
      await tester.pumpWidget(
        setupTestWidget(
          headerStyle: const HeaderStyle(leftChevronVisible: false),
        ),
      );

      final leftChevron = find.widgetWithIcon(
        ShadIconButton,
        Icons.chevron_left,
      );

      final rightChevron = find.widgetWithIcon(
        ShadIconButton,
        Icons.chevron_right,
      );

      expect(leftChevron, findsNothing);
      expect(rightChevron, findsOneWidget);
    },
  );

  testWidgets(
    'When rightChevronVisible is false, do not show the right chevron',
    (tester) async {
      await tester.pumpWidget(
        setupTestWidget(
          headerStyle: const HeaderStyle(rightChevronVisible: false),
        ),
      );

      final leftChevron = find.widgetWithIcon(
        ShadIconButton,
        Icons.chevron_left,
      );

      final rightChevron = find.widgetWithIcon(
        ShadIconButton,
        Icons.chevron_right,
      );

      expect(leftChevron, findsOneWidget);
      expect(rightChevron, findsNothing);
    },
  );

  testWidgets(
    'When availableCalendarFormats has a single format, do not show the FormatButton',
    (tester) async {
      await tester.pumpWidget(
        setupTestWidget(
          availableCalendarFormats: const {CalendarFormat.month: 'Month'},
        ),
      );

      // Only one format available, format button should not render its text
      expect(find.text('Month'), findsNothing);
    },
  );

  testWidgets(
    'When formatButtonVisible is false, do not show the FormatButton',
    (tester) async {
      await tester.pumpWidget(
        setupTestWidget(
          headerStyle: const HeaderStyle(formatButtonVisible: false),
        ),
      );

      // Format button shows the next format text ('2 weeks') when visible;
      // when formatButtonVisible=false, it should not render format text
      expect(find.text('2 weeks'), findsNothing);
    },
  );
}
