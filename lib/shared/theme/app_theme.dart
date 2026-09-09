import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Light + dark themes per docs/03_DESIGN.md. Touch targets >= 56dp (§4).
/// Dark reference: design/mockups/alternatives/home_C_dark_rejected_use_as_darkmode_ref.png
class AppTheme {
  AppTheme._();

  static const fontFamily = 'Tajawal';

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final background = isDark ? AppColors.darkBackground : AppColors.background;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final text = isDark ? const Color(0xFFECEFF1) : AppColors.textPrimary;
    final primary = isDark ? AppColors.darkPrimary : AppColors.primary;
    final outline = isDark ? const Color(0xFF2E3A4B) : AppColors.outline;

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: surface,
      onSurface: text,
      error: AppColors.debt,
      outline: outline,
      secondary: isDark ? AppColors.darkAccent : AppColors.accent,
      secondaryContainer: isDark ? const Color(0xFF3A2F12) : AppColors.accentContainer,
      tertiary: AppColors.payment,
      tertiaryContainer: isDark ? const Color(0xFF14301F) : AppColors.paymentContainer,
      errorContainer: isDark ? const Color(0xFF3A1A1A) : AppColors.debtContainer,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: background,
      brightness: b,
    );

    return base.copyWith(
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
      ),
      textTheme: base.textTheme.apply(bodyColor: text, displayColor: text, fontFamily: fontFamily),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        // 56dp leading slot so AppBackButton is never cramped.
        toolbarHeight: 60,
        iconTheme: IconThemeData(color: text, size: 28),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: isDark ? 0 : 1,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(
              fontFamily: fontFamily, fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(56, 56)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(fontFamily: fontFamily, fontSize: 14),
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: isDark ? const Color(0xFF0B3D30) : AppColors.primary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(24)),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        labelStyle: TextStyle(fontFamily: fontFamily, color: text.withValues(alpha: 0.7)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
