import 'package:flutter/cupertino.dart';

import '../localizations/atomic_localizations.dart';

class TimeUtil {
  static String convertToFormatTime(int timestamp, BuildContext context) {
    if (timestamp <= 0) {
      return '';
    }

    DateTime date;
    date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    if (!context.mounted) {
      return '';
    }

    AtomicLocalizations localizations = AtomicLocalizations.of(context);

    final now = DateTime.now();

    final nowYear = now.year;
    final nowMonth = now.month;
    final nowDay = now.day;
    final nowWeek = (now.weekday + 6) % 7;

    final dateYear = date.year;
    final dateMonth = date.month;
    final dateDay = date.day;
    final dateWeek = (date.weekday + 6) % 7;

    final weekStartDay = now.subtract(Duration(days: nowWeek));
    final weekStartDayComponents = DateTime(weekStartDay.year, weekStartDay.month, weekStartDay.day);

    final dateWeekStartDay = date.subtract(Duration(days: dateWeek));
    final dateWeekStartDayComponents = DateTime(dateWeekStartDay.year, dateWeekStartDay.month, dateWeekStartDay.day);

    if (nowYear == dateYear) {
      if (nowMonth == dateMonth) {
        if (weekStartDayComponents == dateWeekStartDayComponents) {
          if (nowDay == dateDay) {
            return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
          } else {
            final weekdays = [
              localizations.weekdaySunday,
              localizations.weekdayMonday,
              localizations.weekdayTuesday,
              localizations.weekdayWednesday,
              localizations.weekdayThursday,
              localizations.weekdayFriday,
              localizations.weekdaySaturday,
            ];
            return "${weekdays[date.weekday % 7]} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
          }
        } else {
          return "${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
        }
      } else {
        return "${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
      }
    } else {
      return "${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
  }
}