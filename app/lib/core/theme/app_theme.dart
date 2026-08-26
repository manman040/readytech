import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:readytech/core/theme/app_colors.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_typography.dart';

/// Assembles the Material 3 themes.
///
/// The colour scheme is written out rather than generated from a seed. A seeded
/// scheme is convenient but it decides the brand for you; ReadyTech's blue and
/// its reserved "live" teal are product decisions, not tonal-palette output.
abstract final class AppTheme {
  static ThemeData get light => _build(_lightScheme, AppSemanticColors.light);
  static ThemeData get dark => _build(_darkScheme, AppSemanticColors.dark);

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppPalette.blue40,
    onPrimary: AppPalette.white,
    primaryContainer: AppPalette.blue90,
    onPrimaryContainer: AppPalette.blue20,
    secondary: AppPalette.slate70,
    onSecondary: AppPalette.white,
    secondaryContainer: AppPalette.slate10,
    onSecondaryContainer: AppPalette.slate80,
    tertiary: AppPalette.teal50,
    onTertiary: AppPalette.white,
    tertiaryContainer: AppPalette.teal90,
    onTertiaryContainer: AppPalette.teal30,
    error: AppPalette.red50,
    onError: AppPalette.white,
    errorContainer: AppPalette.red90,
    onErrorContainer: AppPalette.red40,
    surface: AppPalette.white,
    onSurface: AppPalette.ink,
    onSurfaceVariant: AppPalette.slate60,
    surfaceContainerLowest: AppPalette.white,
    surfaceContainerLow: AppPalette.slate05,
    surfaceContainer: AppPalette.slate05,
    surfaceContainerHigh: AppPalette.slate10,
    surfaceContainerHighest: AppPalette.slate10,
    outline: AppPalette.slate40,
    outlineVariant: AppPalette.slate20,
    inverseSurface: AppPalette.slate90,
    onInverseSurface: AppPalette.slate10,
    inversePrimary: AppPalette.blue80,
    scrim: Color(0x99000000),
    shadow: Color(0x1A0C111B),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppPalette.blue60,
    onPrimary: AppPalette.blue10,
    primaryContainer: AppPalette.blue30,
    onPrimaryContainer: AppPalette.blue90,
    secondary: AppPalette.slate30,
    onSecondary: AppPalette.slate90,
    secondaryContainer: AppPalette.slate80,
    onSecondaryContainer: AppPalette.slate20,
    tertiary: AppPalette.teal60,
    onTertiary: AppPalette.teal20,
    tertiaryContainer: AppPalette.teal30,
    onTertiaryContainer: AppPalette.teal90,
    error: Color(0xFFF2857E),
    onError: Color(0xFF5C1410),
    errorContainer: Color(0xFF7A1C17),
    onErrorContainer: AppPalette.red90,
    surface: AppPalette.ink,
    onSurface: AppPalette.slate10,
    onSurfaceVariant: AppPalette.slate40,
    surfaceContainerLowest: Color(0xFF070B12),
    surfaceContainerLow: Color(0xFF121926),
    surfaceContainer: Color(0xFF161E2C),
    surfaceContainerHigh: Color(0xFF1C2433),
    surfaceContainerHighest: AppPalette.slate90,
    outline: AppPalette.slate60,
    outlineVariant: Color(0xFF2A3444),
    inverseSurface: AppPalette.slate10,
    onInverseSurface: AppPalette.slate90,
    inversePrimary: AppPalette.blue40,
    scrim: Color(0xCC000000),
    shadow: Color(0x66000000),
  );

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final textTheme = AppTypography.textTheme(
      scheme.onSurface,
      scheme.onSurfaceVariant,
    );
    final isLight = scheme.brightness == Brightness.light;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: isLight
          ? AppPalette.slate05
          : scheme.surfaceContainerLowest,
      splashFactory: InkSparkle.splashFactory,
      extensions: [semantic],

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),

      // Separation comes from a hairline, not a drop shadow. Stacked shadows
      // are what make an interface look busy.
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.borderLg,
          side: BorderSide(color: semantic.hairline),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Touch.buttonHeight),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: Radii.borderMd),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Touch.buttonHeight),
          textStyle: textTheme.labelLarge,
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: Radii.borderMd),
          padding: const EdgeInsets.symmetric(horizontal: Gap.xxl),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(Touch.minTarget, Touch.minTarget),
          textStyle: textTheme.labelLarge,
          shape: const RoundedRectangleBorder(borderRadius: Radii.borderSm),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppPalette.white : scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Gap.lg,
          vertical: Gap.lg,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: scheme.outline),
        labelStyle: textTheme.bodyMedium,
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        border: _fieldBorder(scheme.outlineVariant),
        enabledBorder: _fieldBorder(scheme.outlineVariant),
        focusedBorder: _fieldBorder(scheme.primary, width: 2),
        errorBorder: _fieldBorder(scheme.error),
        focusedErrorBorder: _fieldBorder(scheme.error, width: 2),
        disabledBorder: _fieldBorder(semantic.hairline),
      ),

      dividerTheme: DividerThemeData(
        color: semantic.hairline,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: semantic.neutralContainer,
        side: BorderSide.none,
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.md,
          vertical: Gap.sm,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.borderSm),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheet),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: Radii.borderLg),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: Radii.borderMd),
        insetPadding: const EdgeInsets.all(Gap.lg),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelMedium?.copyWith(color: scheme.onSurface)
              : textTheme.labelMedium,
        ),
      ),

      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: Gap.lg),
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        shape: const RoundedRectangleBorder(borderRadius: Radii.borderMd),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantic.neutralContainer,
        circularTrackColor: semantic.neutralContainer,
      ),

      // A quick, uniform page transition. Platform defaults differ enough
      // between Android and iOS to make shared flows feel inconsistent.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: Radii.borderMd,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Convenience access to the semantic palette.
extension SemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
