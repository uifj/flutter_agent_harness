// Copyright (c) 2021 Simform Solutions. All rights reserved.
// Use of this source code is governed by a MIT-style license
// that can be found in the LICENSE file.

import 'dart:math';
import 'dart:ui';

class Constants {
  Constants._();

  static final Random _random = Random();
  static const int _maxColor = 256;

  static const int hoursADay = 24;
  static const int minutesADay = 1440;

  static final List<String> weekTitles = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  static const Color defaultLiveTimeIndicatorColor = Color(0xFF475569);
  static const Color defaultBorderColor = Color(0xFFE2E8F0);
  static const Color black = Color(0xff000000);
  static const Color white = Color(0xffffffff);
  static const Color offWhite = Color(0xFFF8FAFC);
  static const Color headerBackground = Color(0xFFF1F5F9);
  static Color get randomColor {
    return Color.fromRGBO(
      _random.nextInt(_maxColor),
      _random.nextInt(_maxColor),
      _random.nextInt(_maxColor),
      1,
    );
  }
}
