// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../customization/header_style.dart';
import '../../utils/shad_theme_fallback.dart';
import '../../utils/utils.dart' show CalendarFormat, DayBuilder;

class CalendarHeader extends StatelessWidget {
  final dynamic locale;
  final DateTime focusedMonth;
  final CalendarFormat calendarFormat;
  final HeaderStyle headerStyle;
  final VoidCallback onLeftChevronTap;
  final VoidCallback onRightChevronTap;
  final VoidCallback onHeaderTap;
  final VoidCallback onHeaderLongPress;
  final ValueChanged<CalendarFormat> onFormatButtonTap;
  final Map<CalendarFormat, String> availableCalendarFormats;
  final DayBuilder? headerTitleBuilder;

  const CalendarHeader({
    super.key,
    this.locale,
    required this.focusedMonth,
    required this.calendarFormat,
    required this.headerStyle,
    required this.onLeftChevronTap,
    required this.onRightChevronTap,
    required this.onHeaderTap,
    required this.onHeaderLongPress,
    required this.onFormatButtonTap,
    required this.availableCalendarFormats,
    this.headerTitleBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    final text =
        headerStyle.titleTextFormatter?.call(focusedMonth, locale) ??
        DateFormat.yMMMM(locale).format(focusedMonth);

    CalendarFormat nextFormat() {
      final formats = availableCalendarFormats.keys.toList();
      int id = formats.indexOf(calendarFormat);
      id = (id + 1) % formats.length;
      return formats[id];
    }

    final formatButtonText = headerStyle.formatButtonShowsNext
        ? availableCalendarFormats[nextFormat()]!
        : availableCalendarFormats[calendarFormat]!;

    final effectiveDecoration =
        headerStyle.decoration ??
        (theme != null
            ? BoxDecoration(color: theme.colorScheme.background)
            : const BoxDecoration());

    return ShadThemeFallback(
      child: Container(
        decoration: effectiveDecoration,
        margin: headerStyle.headerMargin,
        padding: headerStyle.headerPadding,
        child: Row(
          children: [
            if (headerStyle.leftChevronVisible)
              Padding(
                padding: headerStyle.leftChevronMargin,
                child: ShadIconButton.ghost(
                  icon: headerStyle.leftChevronIcon,
                  onPressed: onLeftChevronTap,
                  padding: headerStyle.leftChevronPadding,
                ),
              ),
            Expanded(
              child:
                  headerTitleBuilder?.call(context, focusedMonth) ??
                  GestureDetector(
                    onTap: onHeaderTap,
                    onLongPress: onHeaderLongPress,
                    child: Text(
                      text,
                      style:
                          headerStyle.titleTextStyle ??
                          (theme != null
                              ? theme.textTheme.h4.copyWith(
                                  color: theme.colorScheme.foreground,
                                )
                              // Original Slate default when no ShadTheme exists.
                              : const TextStyle(
                                  fontSize: 17.0,
                                  color: Color(0xFF1E293B),
                                )),
                      textAlign: headerStyle.titleCentered
                          ? TextAlign.center
                          : TextAlign.start,
                    ),
                  ),
            ),
            if (headerStyle.formatButtonVisible &&
                availableCalendarFormats.length > 1)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ShadButton.ghost(
                  onPressed: () => onFormatButtonTap(nextFormat()),
                  padding: headerStyle.formatButtonPadding,
                  child: Text(
                    formatButtonText,
                    style:
                        headerStyle.formatButtonTextStyle ??
                        theme?.textTheme.small ??
                        // Original Slate default when no ShadTheme exists.
                        const TextStyle(
                          fontSize: 14.0,
                          color: Color(0xFF475569),
                        ),
                  ),
                ),
              ),
            if (headerStyle.rightChevronVisible)
              Padding(
                padding: headerStyle.rightChevronMargin,
                child: ShadIconButton.ghost(
                  icon: headerStyle.rightChevronIcon,
                  onPressed: onRightChevronTap,
                  padding: headerStyle.rightChevronPadding,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
