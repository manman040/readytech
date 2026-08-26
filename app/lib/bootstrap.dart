import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:readytech/core/config/app_config.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/readytech_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Starts the application.
///
/// Runs everything inside a guarded zone so an error thrown off the widget tree
/// - in a stream listener, a timer, an unawaited future - is logged rather than
/// vanishing. Configuration is validated before anything else, so a missing
/// environment file fails immediately with a message that says what to do
/// instead of surfacing later as a confusing auth error.
Future<void> bootstrap() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final config = AppConfig.fromEnvironment();

      try {
        config.validate();
      } on MissingConfigurationException catch (error) {
        runApp(_ConfigurationErrorApp(message: error.toString()));
        return;
      }

      await Supabase.initialize(
        url: config.supabaseUrl,
        publishableKey: config.supabasePublishableKey,
        // Verbose Supabase logging only outside production.
        debug: !config.flavor.isProduction,
      );

      await configureDependencies(config);

      final logger = getIt<AppLogger>();

      FlutterError.onError = (details) {
        logger.error(
          'Flutter framework error',
          error: details.exception,
          stackTrace: details.stack,
        );
        if (kDebugMode) FlutterError.presentError(details);
      };

      // Errors that escape the framework entirely (platform channels, isolates).
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        logger.error('Uncaught error', error: error, stackTrace: stackTrace);
        return true;
      };

      logger.info('ReadyTech starting', context: 'flavor=${config.flavor.key}');

      runApp(const ReadyTechApp());
    },
    (error, stackTrace) {
      // The logger may not exist yet if the failure happened during setup.
      if (getIt.isRegistered<AppLogger>()) {
        getIt<AppLogger>().error(
          'Unhandled zone error',
          error: error,
          stackTrace: stackTrace,
        );
      } else {
        debugPrint('Unhandled zone error before logging was ready: $error');
      }
    },
  );
}

/// Shown when the app was built without its environment file.
///
/// A developer-facing screen: it names the missing variables so the fix is
/// obvious, rather than leaving a blank screen or a crash on launch.
class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest_outlined, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'ReadyTech is not configured',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
