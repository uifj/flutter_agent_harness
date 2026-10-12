// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/widgets.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../utils/utils.dart' show CalendarFormat;

/// Deprecated: Use [ShadButton.ghost] directly instead.
/// This wrapper is kept for backward compatibility with existing tests.
@Deprecated('Use ShadButton.ghost directly instead')
class FormatButton extends StatelessWidget {
  final CalendarFormat calendarFormat;
  final ValueChanged<CalendarFormat> onTap;
  final TextStyle? textStyle;
  final BoxDecoration decoration;
  final EdgeInsets padding;
  final bool showsNextFormat;
  final Map<CalendarFormat, String> availableCalendarFormats;

  const FormatButton({
    super.key,
    required this.calendarFormat,
    required this.onTap,
    required this.textStyle,
    required this.decoration,
    required this.padding,
    required this.showsNextFormat,
    required this.availableCalendarFormats,
  });

  @override
  Widget build(BuildContext context) {
    return ShadButton.ghost(
      onPressed: () => onTap(_nextFormat()),
      padding: padding,
      child: Text(_formatButtonText, style: textStyle),
    );
  }

  String get _formatButtonText => showsNextFormat
      ? availableCalendarFormats[_nextFormat()]!
      : availableCalendarFormats[calendarFormat]!;

  CalendarFormat _nextFormat() {
    final formats = availableCalendarFormats.keys.toList();
    int id = formats.indexOf(calendarFormat);
    id = (id + 1) % formats.length;

    return formats[id];
  }
}
