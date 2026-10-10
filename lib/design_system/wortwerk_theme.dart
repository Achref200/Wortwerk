import 'package:flutter/material.dart';

abstract final class WortwerkColors {
  static const paper = Color(0xFFF4F1EA);
  static const ink = Color(0xFF1E1D22);
  static const muted = Color(0xFF55525C);
  static const line = Color(0x331E1D22);
  static const streak = Color(0xFFE8590C);
  static const flameRed = Color(0xFFC0453B);
  static const flameCore = Color(0xFFF6E39A);
  static const success = Color(0xFF7CC88A);
  static const a1 = Color(0xFFF5C2DC);
  static const a2 = Color(0xFFD4BDEE);
  static const b1 = Color(0xFFB9D3EE);
  static const b2 = Color(0xFFBFE3C4);
  static const c1 = Color(0xFFF2B890);
  static const c2 = Color(0xFFF6E39A);
  static const glass = Color(0xB8FFFEFC);
}

abstract final class WortwerkRadii {
  static const card = 28.0;
  static const sheet = 36.0;
  static const pill = 999.0;
}

abstract final class WortwerkTypography {
  static const handwritten = TextStyle(
    fontFamily: 'Caveat',
    color: WortwerkColors.ink,
    fontSize: 21,
    fontWeight: FontWeight.w600,
    height: 1.15,
  );
}

abstract final class WortwerkTheme {
  static ThemeData get light {
    const textColor = WortwerkColors.ink;
    final scheme = ColorScheme.fromSeed(
      seedColor: WortwerkColors.ink,
      brightness: Brightness.light,
      surface: WortwerkColors.paper,
      primary: WortwerkColors.ink,
      onPrimary: WortwerkColors.paper,
      secondary: WortwerkColors.streak,
      onSecondary: Colors.white,
      error: const Color(0xFFB3261E),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'DM Sans',
      colorScheme: scheme,
      scaffoldBackgroundColor: WortwerkColors.paper,
      splashFactory: InkSparkle.splashFactory,
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Bricolage Grotesque',
          color: textColor,
          fontSize: 44,
          fontWeight: FontWeight.w800,
          height: 1.05,
          letterSpacing: -1.8,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'Bricolage Grotesque',
          color: textColor,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          height: 1.1,
          letterSpacing: -1,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'Bricolage Grotesque',
          color: textColor,
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.15,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        titleMedium: TextStyle(
          color: textColor,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        bodyLarge: TextStyle(color: textColor, fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(
          color: WortwerkColors.muted,
          fontSize: 14,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
        labelSmall: TextStyle(
          color: WortwerkColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: WortwerkColors.paper,
        foregroundColor: WortwerkColors.ink,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFFFEFC),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WortwerkRadii.card),
          side: const BorderSide(color: WortwerkColors.line, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: WortwerkColors.ink,
          foregroundColor: WortwerkColors.paper,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: WortwerkColors.ink,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: WortwerkColors.line),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFFFFEFC),
        selectedColor: WortwerkColors.a2,
        labelStyle: const TextStyle(
          color: WortwerkColors.ink,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: const StadiumBorder(
          side: BorderSide(color: WortwerkColors.line),
        ),
      ),
      dividerColor: WortwerkColors.line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: WortwerkColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WortwerkRadii.card),
        ),
      ),
    );
  }
}
