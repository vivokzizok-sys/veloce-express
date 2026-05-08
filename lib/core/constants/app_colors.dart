import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF111111);
  static const Color background = Color(0xFFFFF8F7);
  static const Color accent = Color(0xFFE31E24);
  static const Color accentDark = Color(0xFFBA0013);
  static const Color accentLight = Color(0xFFFFE2DE);
  static const Color brandRed = Color(0xFFE31E24);
  static const Color brandGreen = Color(0xFF75D34E);
  static const Color brandYellow = Color(0xFFFFD957);
  static const Color brandCyan = Color(0xFF25BFD0);

  static const Color grey50 = Color(0xFFFFF0EE);
  static const Color grey100 = Color(0xFFF7D8D4);
  static const Color grey200 = Color(0xFFD8DCE2);
  static const Color grey300 = Color(0xFFB8BEC8);
  static const Color grey400 = Color(0xFF8E95A3);
  static const Color grey500 = Color(0xFF667085);
  static const Color grey700 = Color(0xFF344054);

  static const Color success = Color(0xFF22A06B);
  static const Color warning = Color(0xFFFFB020);
  static const Color error = Color(0xFFE5484D);
  static const Color info = Color(0xFF3E7BFA);

  static const Color clientRole = Color(0xFF007AFF);
  static const Color driverRole = Color(0xFF22A06B);
  static const Color adminRole = Color(0xFF111111);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color page(BuildContext context) =>
      isDark(context) ? const Color(0xFF160F0F) : background;

  static Color surface(BuildContext context) =>
      isDark(context) ? const Color(0xFF211717) : white;

  static Color surfaceAlt(BuildContext context) =>
      isDark(context) ? const Color(0xFF2B1F1E) : grey50;

  static Color border(BuildContext context) =>
      isDark(context) ? const Color(0xFF402B29) : const Color(0xFFE7BDB8);

  static Color textPrimary(BuildContext context) =>
      isDark(context) ? const Color(0xFFFFEDEA) : const Color(0xFF291715);

  static Color textSecondary(BuildContext context) =>
      isDark(context) ? const Color(0xFFD8B9B5) : const Color(0xFF5D3F3C);

  static Color accentSoft(BuildContext context) =>
      isDark(context) ? const Color(0xFF421B1D) : accentLight;

  static Color shadow(BuildContext context) => isDark(context)
      ? Colors.black.withValues(alpha: 0.24)
      : const Color(0xFFBA0013).withValues(alpha: 0.08);
}
