// Copyright (c) 2021 Simform Solutions. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../calendar_event_data.dart';
import '../constants.dart';
import '../extensions.dart';
import '../typedefs.dart';
import 'common_components.dart';

class CircularCell extends StatelessWidget {
  /// Date of cell.
  final DateTime date;

  /// List of Events for current date.
  final List<CalendarEventData> events;

  /// Defines if [date] is [DateTime.now] or not.
  final bool shouldHighlight;

  /// Background color of circle around date title.
  final Color backgroundColor;

  /// Title color when title is highlighted.
  final Color highlightedTitleColor;

  /// Color of cell title.
  final Color titleColor;

  /// This class will defines how cell will be displayed.
  /// To get proper view user [CircularCell] with 1 [MonthView.cellAspectRatio].
  const CircularCell({
    super.key,
    required this.date,
    this.events = const [],
    this.shouldHighlight = false,
    this.backgroundColor = Colors.blue,
    this.highlightedTitleColor = Constants.white,
    this.titleColor = Constants.black,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    // Resolve themed colors only when the caller kept the hardcoded defaults.
    final effectiveBackground = backgroundColor == Colors.blue
        ? (theme?.colorScheme.primary ?? backgroundColor)
        : backgroundColor;
    final effectiveHighlightedTitleColor =
        highlightedTitleColor == Constants.white
        ? (theme?.colorScheme.primaryForeground ?? highlightedTitleColor)
        : highlightedTitleColor;
    final effectiveTitleColor = titleColor == Constants.black
        ? (theme?.colorScheme.foreground ?? titleColor)
        : titleColor;
    return Center(
      child: CircleAvatar(
        backgroundColor: shouldHighlight
            ? effectiveBackground
            : Colors.transparent,
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 20,
            color: shouldHighlight
                ? effectiveHighlightedTitleColor
                : effectiveTitleColor,
          ),
        ),
      ),
    );
  }
}

class FilledCell<T extends Object?> extends StatelessWidget {
  /// Date of current cell.
  final DateTime date;

  /// List of events on for current date.
  final List<CalendarEventData<T>> events;

  /// defines date string for current cell.
  final StringProvider? dateStringBuilder;

  /// Defines if cell should be highlighted or not.
  /// If true it will display date title in a circle.
  final bool shouldHighlight;

  /// Defines background color of cell.
  final Color backgroundColor;

  /// Defines highlight color.
  final Color highlightColor;

  /// Color for event tile.
  final Color tileColor;

  /// Called when user taps on any event tile.
  final TileTapCallback<T>? onTileTap;

  /// defines that [date] is in current month or not.
  final bool isInMonth;

  /// defines radius of highlighted date.
  final double highlightRadius;

  /// color of cell title
  final Color titleColor;

  /// color of highlighted cell title
  final Color highlightedTitleColor;

  /// This class will defines how cell will be displayed.
  /// This widget will display all the events as tile below date title.
  const FilledCell({
    super.key,
    required this.date,
    required this.events,
    this.isInMonth = false,
    this.shouldHighlight = false,
    this.backgroundColor = Colors.blue,
    this.highlightColor = Colors.blue,
    this.onTileTap,
    this.tileColor = Colors.blue,
    this.highlightRadius = 11,
    this.titleColor = Constants.black,
    this.highlightedTitleColor = Constants.white,
    this.dateStringBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    // Resolve themed colors only when the caller kept the hardcoded defaults.
    final effectiveBackground = backgroundColor == Colors.blue
        ? (theme?.colorScheme.background ?? backgroundColor)
        : backgroundColor;
    final effectiveHighlightColor = highlightColor == Colors.blue
        ? (theme?.colorScheme.primary ?? highlightColor)
        : highlightColor;
    final effectiveTitleColor = titleColor == Constants.black
        ? (theme?.colorScheme.foreground ?? titleColor)
        : titleColor;
    final effectiveHighlightedTitleColor =
        highlightedTitleColor == Constants.white
        ? (theme?.colorScheme.primaryForeground ?? highlightedTitleColor)
        : highlightedTitleColor;
    return Container(
      color: effectiveBackground,
      child: Column(
        children: [
          const SizedBox(height: 5.0),
          CircleAvatar(
            radius: highlightRadius,
            backgroundColor: shouldHighlight
                ? effectiveHighlightColor
                : Colors.transparent,
            child: Text(
              dateStringBuilder?.call(date) ?? '${date.day}',
              style: TextStyle(
                color: shouldHighlight
                    ? effectiveHighlightedTitleColor
                    : isInMonth
                    ? effectiveTitleColor
                    : effectiveTitleColor.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ),
          if (events.isNotEmpty)
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 5.0),
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      events.length,
                      (index) => GestureDetector(
                        onTap: () =>
                            onTileTap?.call(events[index], events[index].date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: events[index].color,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                          margin: const EdgeInsets.symmetric(
                            vertical: 2.0,
                            horizontal: 3.0,
                          ),
                          padding: const EdgeInsets.all(2.0),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  events[index].title,
                                  overflow: TextOverflow.clip,
                                  maxLines: 1,
                                  style:
                                      events[0].titleStyle ??
                                      TextStyle(
                                        color: events[index].color.accent,
                                        fontSize: 12,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MonthPageHeader extends CalendarPageHeader {
  /// A header widget to display on month view.
  const MonthPageHeader({
    super.key,
    VoidCallback? onNextMonth,
    super.onTitleTapped,
    VoidCallback? onPreviousMonth,
    super.iconColor,
    super.backgroundColor,
    StringProvider? dateStringBuilder,
    required super.date,
    super.headerStyle,
  }) : super(
         onNextDay: onNextMonth,
         onPreviousDay: onPreviousMonth,
         dateStringBuilder:
             dateStringBuilder ?? MonthPageHeader._monthStringBuilder,
       );

  static String _monthStringBuilder(DateTime date, {DateTime? secondaryDate}) =>
      '${date.month} - ${date.year}';
}

class WeekDayTile extends StatelessWidget {
  /// Index of week day.
  final int dayIndex;

  /// display week day
  final String Function(int)? weekDayStringBuilder;

  /// Background color of single week day tile.
  final Color backgroundColor;

  /// Should display border or not.
  final bool displayBorder;

  /// Style for week day string.
  final TextStyle? textStyle;

  /// Title for week day in month view.
  const WeekDayTile({
    super.key,
    required this.dayIndex,
    this.backgroundColor = Constants.white,
    this.displayBorder = true,
    this.textStyle,
    this.weekDayStringBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    // Resolve themed colors only when the caller kept the hardcoded defaults.
    final effectiveBackground = backgroundColor == Constants.white
        ? (theme?.colorScheme.background ?? backgroundColor)
        : backgroundColor;
    final effectiveBorderColor =
        theme?.colorScheme.border ?? Constants.defaultBorderColor;
    final effectiveTextColor = theme?.colorScheme.foreground ?? Constants.black;
    return Container(
      alignment: Alignment.center,
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      decoration: BoxDecoration(
        color: effectiveBackground,
        border: displayBorder
            ? Border.all(color: effectiveBorderColor, width: 0.5)
            : null,
      ),
      child: Text(
        weekDayStringBuilder?.call(dayIndex) ?? Constants.weekTitles[dayIndex],
        style: textStyle ?? TextStyle(fontSize: 17, color: effectiveTextColor),
      ),
    );
  }
}
