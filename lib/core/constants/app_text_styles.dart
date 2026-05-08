import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  const AppTextStyles._();

  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle title1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle title3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: AppColors.grey500,
  );

  static const TextStyle captionMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: AppColors.grey500,
  );

  static const TextStyle label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    color: AppColors.grey500,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );

  static const TextStyle buttonSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        primary: AppColors.accent,
        surface: AppColors.white,
      ),
      fontFamily: 'IBM Plex Sans Arabic',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.accentDark,
        ),
        iconTheme: IconThemeData(color: AppColors.black),
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: AppColors.black,
            displayColor: AppColors.black,
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.grey400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardColor: AppColors.white,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white.withValues(alpha: 0.94),
        indicatorColor: AppColors.accentLight,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppTextStyles.captionMedium.copyWith(
            color: states.contains(WidgetState.selected)
                ? AppColors.accentDark
                : AppColors.grey500,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accentDark
                : AppColors.grey500,
          ),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.dark,
        primary: AppColors.accent,
      ),
      fontFamily: 'IBM Plex Sans Arabic',
    );
    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF101418),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF101418),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: AppColors.accent,
        ),
        iconTheme: IconThemeData(color: Color(0xFFF5F7FA)),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
            bodyColor: const Color(0xFFF5F7FA),
            displayColor: const Color(0xFFF5F7FA),
          ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2B1F1E),
        hintStyle: AppTextStyles.body.copyWith(color: const Color(0xFFAAB2C0)),
        prefixIconColor: const Color(0xFFAAB2C0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardColor: const Color(0xFF171C22),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF211717),
        indicatorColor: const Color(0xFF421B1D),
        labelTextStyle: WidgetStatePropertyAll(
          AppTextStyles.captionMedium.copyWith(color: AppColors.accentLight),
        ),
      ),
    );
  }
}
