import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
}

abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 260);
}

abstract final class AppElevation {
  static List<BoxShadow> soft(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.08),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ];
}
