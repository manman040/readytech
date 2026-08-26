/// Build flavors supported by ReadyTech.
///
/// The flavor is injected at compile time via `--dart-define-from-file` and is
/// the single switch that separates sandbox payment credentials, demo data and
/// verbose logging from production behaviour.
enum AppFlavor {
  development('development'),
  staging('staging'),
  production('production')
  ;

  const AppFlavor(this.key);

  /// Value expected in the `FLAVOR` compile-time variable.
  final String key;

  static AppFlavor fromKey(String value) {
    return AppFlavor.values.firstWhere(
      (flavor) => flavor.key == value,
      orElse: () => AppFlavor.development,
    );
  }

  bool get isDevelopment => this == AppFlavor.development;
  bool get isStaging => this == AppFlavor.staging;
  bool get isProduction => this == AppFlavor.production;

  /// Non-production builds may surface developer affordances such as demo mode.
  bool get allowsDemoTooling => !isProduction;
}
