import 'package:flutter/material.dart';

/// Palette verified against WCAG in docs/03_DESIGN.md §2. Do not "eyeball" changes.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0B5D48); // 7.21:1 on background
  static const primaryLight = Color(0xFF0F7B5F);
  static const onPrimary = Color(0xFFFFFFFF);

  static const debt = Color(0xFFB71C1C); // أخذ
  static const debtContainer = Color(0xFFFFF1F0);
  static const payment = Color(0xFF1B7F3B); // دفع
  static const paymentContainer = Color(0xFFEAF6EE);

  static const accent = Color(0xFF8A6200); // gold, 5.18:1 on accentContainer
  static const accentContainer = Color(0xFFFFF6E0);

  static const background = Color(0xFFF7F5F0);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1B1F1E);
  static const textSecondary = Color(0xFF5F6B68);
  static const outline = Color(0xFFDDD9D0);

  // Dark mode (phase 2) — reference: alternatives/home_C_dark
  static const darkBackground = Color(0xFF0F1623);
  static const darkSurface = Color(0xFF1A2332);
  static const darkPrimary = Color(0xFF2E9D7E);
  static const darkAccent = Color(0xFFE0B25A);
}
