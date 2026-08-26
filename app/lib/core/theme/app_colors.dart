import 'package:flutter/material.dart';

/// The raw ReadyTech palette.
///
/// The identity is deliberately cool and precise: a confident engineering blue
/// for actions, a teal reserved exclusively for "live" states (a technician
/// moving, a realtime channel connected), and a wide neutral ramp that does the
/// heavy lifting. Delivery apps lean on warm oranges and greens; ReadyTech
/// should read as instrumentation, not as food arriving.
///
/// Nothing outside this file should hardcode a colour. Widgets read from
/// `Theme.of(context).colorScheme` or from [AppSemanticColors].
abstract final class AppPalette {
  // Brand blue - actions, focus, the primary CTA.
  static const blue10 = Color(0xFF001849);
  static const blue20 = Color(0xFF002A78);
  static const blue30 = Color(0xFF0F3FA8);
  static const blue40 = Color(0xFF1F4FD8);
  static const blue50 = Color(0xFF4470E8);
  static const blue60 = Color(0xFF6E92F0);
  static const blue80 = Color(0xFFB6C8F8);
  static const blue90 = Color(0xFFDCE4FC);
  static const blue95 = Color(0xFFEEF2FE);

  // Teal - reserved for realtime and live signals only. Overusing this colour
  // costs it its meaning.
  static const teal20 = Color(0xFF00332F);
  static const teal30 = Color(0xFF00564F);
  static const teal40 = Color(0xFF00786D);
  static const teal50 = Color(0xFF00A192);
  static const teal60 = Color(0xFF17C3B2);
  static const teal90 = Color(0xFFC9F2ED);

  // Neutrals - the structural colours of the product.
  static const ink = Color(0xFF0C111B);
  static const slate90 = Color(0xFF1A2231);
  static const slate80 = Color(0xFF2B3648);
  static const slate70 = Color(0xFF445064);
  static const slate60 = Color(0xFF5B6779);
  static const slate50 = Color(0xFF7A8698);
  static const slate40 = Color(0xFF9BA5B4);
  static const slate30 = Color(0xFFC3CAD5);
  static const slate20 = Color(0xFFDFE3EA);
  static const slate10 = Color(0xFFEEF1F5);
  static const slate05 = Color(0xFFF6F8FA);
  static const white = Color(0xFFFFFFFF);

  // Status colours.
  static const green40 = Color(0xFF14804A);
  static const green50 = Color(0xFF1E9E63);
  static const green90 = Color(0xFFD6F2E2);

  static const amber40 = Color(0xFFB4740B);
  static const amber50 = Color(0xFFE0930F);
  static const amber90 = Color(0xFFFDEFD3);

  static const red40 = Color(0xFFB3261E);
  static const red50 = Color(0xFFD6453D);
  static const red90 = Color(0xFFFBE0DE);
}

/// Meaning-carrying colours that Material's [ColorScheme] has no slot for.
///
/// Registered as a [ThemeExtension] so light and dark each supply their own
/// values and no widget has to branch on brightness.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.live,
    required this.onLive,
    required this.liveContainer,
    required this.onLiveContainer,
    required this.neutralContainer,
    required this.onNeutralContainer,
    required this.hairline,
    required this.skeletonBase,
    required this.skeletonHighlight,
  });

  /// Completed, paid, verified, online.
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color onSuccessContainer;

  /// Needs attention but is not an error: approval pending, warranty expiring.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Realtime activity: technician moving, channel connected.
  final Color live;
  final Color onLive;
  final Color liveContainer;
  final Color onLiveContainer;

  /// Inert states: cancelled, draft, not started.
  final Color neutralContainer;
  final Color onNeutralContainer;

  /// One physical pixel divider. Preferred over elevation for separation.
  final Color hairline;

  final Color skeletonBase;
  final Color skeletonHighlight;

  static const light = AppSemanticColors(
    success: AppPalette.green50,
    onSuccess: AppPalette.white,
    successContainer: AppPalette.green90,
    onSuccessContainer: AppPalette.green40,
    warning: AppPalette.amber50,
    onWarning: AppPalette.white,
    warningContainer: AppPalette.amber90,
    onWarningContainer: AppPalette.amber40,
    live: AppPalette.teal50,
    onLive: AppPalette.white,
    liveContainer: AppPalette.teal90,
    onLiveContainer: AppPalette.teal30,
    neutralContainer: AppPalette.slate10,
    onNeutralContainer: AppPalette.slate60,
    hairline: AppPalette.slate20,
    skeletonBase: AppPalette.slate10,
    skeletonHighlight: AppPalette.slate05,
  );

  static const dark = AppSemanticColors(
    success: AppPalette.green50,
    onSuccess: AppPalette.ink,
    successContainer: Color(0xFF0C3A24),
    onSuccessContainer: Color(0xFF8EDCB4),
    warning: AppPalette.amber50,
    onWarning: AppPalette.ink,
    warningContainer: Color(0xFF422D06),
    onWarningContainer: Color(0xFFF5CE86),
    live: AppPalette.teal60,
    onLive: AppPalette.ink,
    liveContainer: AppPalette.teal20,
    onLiveContainer: Color(0xFF7FE0D4),
    neutralContainer: AppPalette.slate80,
    onNeutralContainer: AppPalette.slate30,
    hairline: Color(0xFF2A3444),
    skeletonBase: Color(0xFF202B3B),
    skeletonHighlight: Color(0xFF2A3648),
  );

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? live,
    Color? onLive,
    Color? liveContainer,
    Color? onLiveContainer,
    Color? neutralContainer,
    Color? onNeutralContainer,
    Color? hairline,
    Color? skeletonBase,
    Color? skeletonHighlight,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      live: live ?? this.live,
      onLive: onLive ?? this.onLive,
      liveContainer: liveContainer ?? this.liveContainer,
      onLiveContainer: onLiveContainer ?? this.onLiveContainer,
      neutralContainer: neutralContainer ?? this.neutralContainer,
      onNeutralContainer: onNeutralContainer ?? this.onNeutralContainer,
      hairline: hairline ?? this.hairline,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSemanticColors(
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      onWarning: mix(onWarning, other.onWarning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      live: mix(live, other.live),
      onLive: mix(onLive, other.onLive),
      liveContainer: mix(liveContainer, other.liveContainer),
      onLiveContainer: mix(onLiveContainer, other.onLiveContainer),
      neutralContainer: mix(neutralContainer, other.neutralContainer),
      onNeutralContainer: mix(onNeutralContainer, other.onNeutralContainer),
      hairline: mix(hairline, other.hairline),
      skeletonBase: mix(skeletonBase, other.skeletonBase),
      skeletonHighlight: mix(skeletonHighlight, other.skeletonHighlight),
    );
  }
}
