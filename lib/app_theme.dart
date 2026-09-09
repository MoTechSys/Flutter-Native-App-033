// ============================================================
// كِتابي - الثيم: "مكتبة ليلية فاخرة"
// فحمي/كحلي داكن + جوزي + ذهبي مصقول + عاجي، عناوين Serif
// ============================================================

import 'package:flutter/material.dart';

class Palette {
  static const night = Color(0xFF12161F); // خلفية
  static const nightSoft = Color(0xFF1A2030); // بطاقات
  static const walnut = Color(0xFF3B2A1E); // جوزي
  static const walnutLight = Color(0xFF5A4333);
  static const gold = Color(0xFFD4AF37);
  static const goldDim = Color(0xFF9E8329);
  static const ivory = Color(0xFFF3EDE0);
  static const ivoryDim = Color(0xFFB8B2A4);
  static const success = Color(0xFF3FBF7F);
  static const danger = Color(0xFFE5484D);
  static const line = Color(0xFF2A3142);
}

class AppText {
  /// خط العناوين (Serif) — يعطي الطابع الأدبي
  static const serif = 'serif';

  /// نمط عنوان Serif سريع
  static TextStyle serifStyle(double size, {Color color = Palette.ivory, FontWeight weight = FontWeight.w700}) =>
      TextStyle(fontFamily: serif, fontSize: size, color: color, fontWeight: weight);
}

ThemeData buildKitabiTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: Palette.night,
    colorScheme: const ColorScheme.dark(
      primary: Palette.gold,
      onPrimary: Palette.night,
      secondary: Palette.walnutLight,
      surface: Palette.nightSoft,
      onSurface: Palette.ivory,
      error: Palette.danger,
    ),
    textTheme: base.textTheme
        .apply(bodyColor: Palette.ivory, displayColor: Palette.ivory)
        .copyWith(
          headlineSmall: const TextStyle(
            fontFamily: AppText.serif,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Palette.ivory,
          ),
          titleLarge: const TextStyle(
            fontFamily: AppText.serif,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Palette.ivory,
          ),
          titleMedium: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Palette.ivory,
          ),
          bodyMedium: const TextStyle(fontSize: 14, color: Palette.ivory),
          bodySmall: const TextStyle(fontSize: 12, color: Palette.ivoryDim),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Palette.night,
      foregroundColor: Palette.ivory,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: AppText.serif,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Palette.ivory,
      ),
    ),
    cardTheme: CardThemeData(
      color: Palette.nightSoft,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Palette.line),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.nightSoft,
      labelStyle: const TextStyle(color: Palette.ivoryDim),
      hintStyle: const TextStyle(color: Palette.ivoryDim),
      prefixIconColor: Palette.goldDim,
      suffixIconColor: Palette.ivoryDim,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Palette.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Palette.gold,
        foregroundColor: Palette.night,
        minimumSize: const Size.fromHeight(50),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Palette.gold,
        side: const BorderSide(color: Palette.gold),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Palette.gold),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Palette.nightSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        fontFamily: AppText.serif,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Palette.ivory,
      ),
      contentTextStyle: const TextStyle(color: Palette.ivoryDim, height: 1.5),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Palette.nightSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: Palette.line),
    chipTheme: ChipThemeData(
      backgroundColor: Palette.nightSoft,
      selectedColor: Palette.gold.withValues(alpha: 0.18),
      side: const BorderSide(color: Palette.line),
      labelStyle: const TextStyle(color: Palette.ivory),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Palette.nightSoft,
      indicatorColor: Palette.gold.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? Palette.gold
              : Palette.ivoryDim,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w400,
          color: s.contains(WidgetState.selected)
              ? Palette.gold
              : Palette.ivoryDim,
        ),
      ),
    ),
  );
}
