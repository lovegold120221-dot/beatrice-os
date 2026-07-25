import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized design tokens mirroring the root Next.js app's Tailwind palette.
class AppColors {
  // Surfaces
  static const black = Color(0xFF000000);
  static const zinc900 = Color(0xFF18181B); // page bg behind phone frame
  static const surface0a = Color(0xFF0A0A0A); // modal/apps screen
  static const sidebar = Color(0xFF111111);
  static const card1a = Color(0xFF1A1A1A); // cards, modal inner
  static const chip2121 = Color(0xFF212121); // buttons, inputs
  static const hover2f = Color(0xFF2F2F2F); // hover / user bubble
  static const attach2a = Color(0xFF2A2A2A);
  static const sourceHover = Color(0xFF333333);
  static const codeBody = Color(0xFF121212);
  static const codeHeader = Color(0xFF1E1E1E);
  static const divider = Color(0xFF262626); // neutral-800
  static const dividerSubtle = Color(0xFF1F1F1F);

  // Text
  static const white = Color(0xFFFFFFFF);
  static const neutral200 = Color(0xFFE5E5E5); // model bubble body
  static const neutral300 = Color(0xFFD4D4D4); // header buttons idle
  static const neutral400 = Color(0xFFA3A3A3); // labels/placeholders
  static const neutral500 = Color(0xFF737373);
  static const neutral600 = Color(0xFF525252); // dates

  // Accents
  static const emerald = Color(0xFF34D399);
  static const emeraldBg = Color(0xFF10B981);
  static const blue = Color(0xFF60A5FA);
  static const blueBg = Color(0xFF3B82F6);
  static const purple = Color(0xFFA855F7);
  static const red = Color(0xFFEF4444);
  static const red400 = Color(0xFFF87171);
  static const yellow = Color(0xFFFACC15);
  static const thinkingBadgeBg = Color(0xFF202936);
  static const thinkingBadgeText = Color(0xFF4BA1FF);
  static const linkBlue = Color(0xFF60A5FA);
  static const inlineCodeText = Color(0xFF93C5FD);
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.black,
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white,
      surface: AppColors.sidebar,
      onSurface: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    cardColor: AppColors.card1a,
    dividerColor: AppColors.dividerSubtle,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    useMaterial3: true,
  );

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: const ColorScheme.light(
      primary: Colors.black,
      secondary: Colors.black,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    cardColor: const Color(0xFFF4F4F5),
    dividerColor: const Color(0xFFE4E4E7),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    useMaterial3: true,
  );

  /// Resolve the stored theme string ('light' | 'dark' | 'system') to a
  /// ThemeData, respecting the platform brightness for 'system'.
  static ThemeData resolve(String theme, Brightness platformBrightness) {
    switch (theme) {
      case 'light':
        return lightTheme;
      case 'dark':
        return darkTheme;
      default:
        return platformBrightness == Brightness.dark ? darkTheme : lightTheme;
    }
  }
}
