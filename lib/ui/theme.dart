import 'package:flutter/material.dart';

/// The colours of the game (warm chai tones).
class AppColors {
  AppColors._();

  static const Color cream = Color(0xFFFFF4E0);
  static const Color creamDark = Color(0xFFF3DDB2);
  static const Color paper = Color(0xFFFFFBF2);
  static const Color saffron = Color(0xFFF4A024);
  static const Color saffronDark = Color(0xFFC77D0A);
  static const Color chai = Color(0xFF8B4A1A);
  static const Color chaiLight = Color(0xFFC98B4E);
  static const Color brown = Color(0xFF3E2210);
  static const Color leaf = Color(0xFF3C8D40);
  static const Color leafDark = Color(0xFF2B6B2F);
  static const Color chili = Color(0xFFD6453D);
  static const Color gold = Color(0xFFFFC107);
  static const Color ink = Color(0xFF2B1A0E);
  static const Color muted = Color(0xFF7A6652);
  static const Color line = Color(0xFFE6D2AC);
  static const Color disabled = Color(0xFFCDBFA6);
}

/// The one theme of the game. There is no dark theme: the game has its own look.
ThemeData buildTheme() {
  final ColorScheme base = ColorScheme.fromSeed(
    seedColor: AppColors.saffron,
    brightness: Brightness.light,
    surface: AppColors.cream,
  );
  final ColorScheme scheme = base.copyWith(
    primary: AppColors.chai,
    onSurface: AppColors.ink,
    secondary: AppColors.saffron,
    error: AppColors.chili,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cream,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    dividerColor: AppColors.line,
  );
}

/// The button look used everywhere: rounded, bold, [color] when enabled.
ButtonStyle gameButtonStyle({Color color = AppColors.leaf, double minWidth = 88}) {
  return FilledButton.styleFrom(
    backgroundColor: color,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.disabled,
    disabledForegroundColor: Colors.white,
    minimumSize: Size(minWidth, 40),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}
