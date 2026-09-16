// Copyright 2019 Aleksander Woźniak
// SPDX-License-Identifier: Apache-2.0

import 'package:board_panel/src/utils/utils.dart';
import 'package:flutter/foundation.dart';

ValueKey<String> dateToKey(DateTime date, {String prefix = ''}) {
  return ValueKey('$prefix${date.year}-${date.month}-${date.day}');
}

const calendarFormatMap = {
  CalendarFormat.month: 'Month',
  CalendarFormat.twoWeeks: 'Two weeks',
  CalendarFormat.week: 'week',
};
