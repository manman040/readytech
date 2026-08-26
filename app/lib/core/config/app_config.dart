import 'package:readytech/core/config/app_flavor.dart';

/// Immutable, compile-time application configuration.
///
/// Values arrive through `--dart-define-from-file=env/<flavor>.json` so that no
/// credential is ever committed to the repository or bundled as a readable
/// asset. Only client-safe values live here: the Supabase publishable key is
/// designed for client use and is protected by Row Level Security. Secrets such
/// as the Supabase service-role key or the ToyyibPay secret key are never
/// referenced by the Flutter application - they exist only inside Edge
/// Functions.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.googleMapsApiKey,
    required this.demoModeEnabled,
  });

  /// Reads configuration from compile-time environment variables.
  factory AppConfig.fromEnvironment() {
    const flavorKey = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'development',
    );
    final flavor = AppFlavor.fromKey(flavorKey);

    return AppConfig(
      flavor: flavor,
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      googleMapsApiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
      // Demo mode can never be switched on in a production build, regardless of
      // what the environment file says.
      demoModeEnabled:
          const bool.fromEnvironment('DEMO_MODE') && flavor.allowsDemoTooling,
    );
  }

  final AppFlavor flavor;
  final String supabaseUrl;
  final String supabasePublishableKey;
  final String googleMapsApiKey;
  final bool demoModeEnabled;

  bool get hasSupabaseCredentials =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  bool get hasMapsCredentials => googleMapsApiKey.isNotEmpty;

  /// Fails fast at startup rather than surfacing confusing auth errors later.
  ///
  /// Throws [MissingConfigurationException] listing every absent variable so a
  /// developer fixes the whole environment file in one pass.
  void validate() {
    final missing = <String>[
      if (supabaseUrl.isEmpty) 'SUPABASE_URL',
      if (supabasePublishableKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY',
    ];

    if (missing.isNotEmpty) {
      throw MissingConfigurationException(missing);
    }
  }
}

/// Raised when the build was started without the required environment file.
class MissingConfigurationException implements Exception {
  const MissingConfigurationException(this.missingKeys);

  final List<String> missingKeys;

  @override
  String toString() =>
      'Missing required configuration: ${missingKeys.join(', ')}. '
      'Run with --dart-define-from-file=env/development.json '
      '(copy env/development.json.example to get started).';
}
