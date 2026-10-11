import 'package:flutter/material.dart';

/// Nuvio design tokens, ported from the official web client's CSS
/// (css/base.css) and tuned for Flutter TV rendering.
///
/// The web client's jank comes from DOM + CSS transitions on TV Chromium.
/// Flutter renders through Impeller/Skia, so we keep the same visual
/// language but can afford richer motion (hero swaps, scale focus, fades).
class NuvioColors {
  const NuvioColors._();

  static const Color bg = Color(0xFF0D0D0D);
  static const Color bgElevated = Color(0xFF1A1A1A);
  static const Color card = Color(0xFF222222);
  static const Color cardFocused = Color(0xFF303030);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textTertiary = Color(0xFF808080);
  static const Color border = Color(0xFF333333);
  static const Color error = Color(0xFFCF6679);
  static const Color errorBg = Color(0x2ECF6679);
  static const Color accent = Color(0xFF8B5CF6); // Nuvio violet
  static const Color progress = Color(0xFF8B5CF6);
}

/// TV-safe layout metrics from the web client's CSS custom properties.
class NuvioSpacing {
  const NuvioSpacing._();

  /// 1080p baseline scaled at runtime by [NuvioMetrics].
  static const double safeGutter = 32;
  static const double safeGutterWide = 40;
  static const double cardGap = 14;
  static const double cardRadius = 16;
  static const double buttonHeight = 60;
  static const double controlSize = 64;
  static const double posterWidth = 176; // 2:3 poster at HD1080
  static const double posterHeight = 264;
  static const double cardFocusScale = 1.1;
}

/// Theme data for the app. Custom user themes (accent color mixing like the
/// web client's customThemePalette) layer on top of this baseline.
ThemeData buildNuvioTheme({Color? accent}) {
  final effectiveAccent = accent ?? NuvioColors.accent;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: NuvioColors.bg,
    colorScheme: ColorScheme.dark(
      surface: NuvioColors.bg,
      surfaceContainerHighest: NuvioColors.card,
      primary: effectiveAccent,
      secondary: effectiveAccent,
      error: NuvioColors.error,
    ),
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      displayLarge: TextStyle(
          fontSize: 44, fontWeight: FontWeight.w800, color: NuvioColors.text),
      displayMedium: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w700, color: NuvioColors.text),
      headlineLarge: TextStyle(
          fontSize: 30, fontWeight: FontWeight.w700, color: NuvioColors.text),
      headlineMedium: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w600, color: NuvioColors.text),
      titleLarge: TextStyle(
          fontSize: 20, fontWeight: FontWeight.w600, color: NuvioColors.text),
      titleMedium: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w600, color: NuvioColors.text),
      bodyLarge: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w400, color: NuvioColors.text),
      bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: NuvioColors.textSecondary),
      bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: NuvioColors.textTertiary),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: NuvioColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NuvioSpacing.cardRadius),
        side: const BorderSide(color: NuvioColors.border),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: NuvioColors.bgElevated,
      contentTextStyle: TextStyle(color: NuvioColors.text),
    ),
  );
}
