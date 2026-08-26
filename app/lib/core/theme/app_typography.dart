import 'package:flutter/material.dart';

/// The ReadyTech type scale.
///
/// Built on the platform UI font rather than a downloaded family: a webfont
/// fetched at runtime is a network dependency on the first frame, and this app
/// has to work on a bad connection in someone's office. Hierarchy comes from
/// weight, size and letter spacing instead.
abstract final class AppTypography {
  /// Tighter tracking on large text, looser on small text, which is what keeps
  /// headings from looking loose and captions from looking cramped.
  static TextTheme textTheme(Color onSurface, Color onSurfaceVariant) {
    return TextTheme(
      // Reserved for the splash wordmark and empty-state hero numbers.
      displaySmall: TextStyle(
        fontSize: 36,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        color: onSurface,
      ),

      // Screen titles.
      headlineMedium: TextStyle(
        fontSize: 28,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: onSurface,
      ),

      // Section headers and card titles.
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.35,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),

      // Body copy.
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: onSurfaceVariant,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.45,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.1,
        color: onSurfaceVariant,
      ),

      // Buttons and chips.
      labelLarge: TextStyle(
        fontSize: 15,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: onSurface,
      ),
      labelMedium: TextStyle(
        fontSize: 13,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: onSurfaceVariant,
      ),

      // Overlines: status chips, metadata rows.
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.2,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: onSurfaceVariant,
      ),
    );
  }

  /// Tabular figures for money, distances and ETAs, so digits do not shift
  /// width as a value updates in realtime.
  static const tabularFigures = [FontFeature.tabularFigures()];
}
