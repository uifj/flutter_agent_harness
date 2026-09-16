// Copyright (c) 2021 Simform Solutions. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../utils/shad_theme_fallback.dart';
import '../constants.dart';
import '../style/calendar_header_style.dart';
import '../typedefs.dart';

class CalendarPageHeader extends StatelessWidget {
  /// When user taps on right arrow.
  final VoidCallback? onNextDay;

  /// When user taps on left arrow.
  final VoidCallback? onPreviousDay;

  /// When user taps on title.
  final AsyncCallback? onTitleTapped;

  /// Date of month/day.
  final DateTime date;

  /// Secondary date. This date will be used when we need to define a
  /// range of dates.
  /// [date] can be starting date and [secondaryDate] can be end date.
  final DateTime? secondaryDate;

  /// Provides string to display as title.
  final StringProvider dateStringBuilder;

  // TODO: Need to remove after next release
  /// background color of header.
  @Deprecated('Use Header Style to provide background')
  final Color backgroundColor;

  // TODO: Need to remove after next release
  /// Color of icons at both sides of header.
  @Deprecated('Use Header Style to provide icon color')
  final Color iconColor;

  /// Style for Calendar's header
  final CalendarHeaderStyle headerStyle;

  /// Common header for month and day view In this header user can define format
  /// in which date will be displayed by providing [dateStringBuilder] function.
  const CalendarPageHeader({
    super.key,
    required this.date,
    required this.dateStringBuilder,
    this.onNextDay,
    this.onTitleTapped,
    this.onPreviousDay,
    this.secondaryDate,
    @Deprecated('Use Header Style to provide background')
    this.backgroundColor = Constants.headerBackground,
    @Deprecated('Use Header Style to provide icon color')
    this.iconColor = Constants.black,
    this.headerStyle = const CalendarHeaderStyle(),
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.maybeOf(context);
    // Resolve themed colors only when the caller kept the hardcoded defaults.
    final effectiveBackground = backgroundColor == Constants.headerBackground
        ? (theme?.colorScheme.muted ?? backgroundColor)
        : backgroundColor;
    final effectiveIconColor = iconColor == Constants.black
        ? (theme?.colorScheme.foreground ?? iconColor)
        : iconColor;
    return ShadThemeFallback(
      child: Container(
        margin: headerStyle.headerMargin,
        padding: headerStyle.headerPadding,
        decoration:
            // ignore_for_file: deprecated_member_use_from_same_package
            headerStyle.decoration ?? BoxDecoration(color: effectiveBackground),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (headerStyle.leftIconVisible)
              ShadIconButton.ghost(
                onPressed: onPreviousDay,
                padding: headerStyle.leftIconPadding,
                // Sized to fit the 30px chevron plus the header padding
                // (the default 40x40 icon button would overflow).
                width: 30 + headerStyle.leftIconPadding.horizontal,
                height: 30 + headerStyle.leftIconPadding.vertical,
                icon:
                    headerStyle.leftIcon ??
                    Icon(
                      LucideIcons.chevronLeft,
                      size: 30,
                      color: effectiveIconColor,
                    ),
              ),
            Expanded(
              child: InkWell(
                onTap: onTitleTapped,
                child: Text(
                  dateStringBuilder(date, secondaryDate: secondaryDate),
                  textAlign: headerStyle.titleAlign,
                  style: headerStyle.headerTextStyle,
                ),
              ),
            ),
            if (headerStyle.rightIconVisible)
              ShadIconButton.ghost(
                onPressed: onNextDay,
                padding: headerStyle.rightIconPadding,
                // Sized to fit the 30px chevron plus the header padding.
                width: 30 + headerStyle.rightIconPadding.horizontal,
                height: 30 + headerStyle.rightIconPadding.vertical,
                icon:
                    headerStyle.rightIcon ??
                    Icon(
                      LucideIcons.chevronRight,
                      size: 30,
                      color: effectiveIconColor,
                    ),
              ),
          ],
        ),
      ),
    );
  }
}
