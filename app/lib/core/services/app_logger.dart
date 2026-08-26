import 'package:logger/logger.dart';
import 'package:readytech/core/config/app_flavor.dart';

/// Logging contract used everywhere in the app.
///
/// An interface rather than a direct `logger` dependency so that a crash
/// reporter can be attached in a later phase without touching call sites, and
/// so tests can assert on what was logged.
abstract interface class AppLogger {
  void debug(String message, {Object? context});
  void info(String message, {Object? context});
  void warn(String message, {Object? error, StackTrace? stackTrace});
  void error(String message, {Object? error, StackTrace? stackTrace});
}

/// Console logger backed by the `logger` package.
///
/// Verbosity follows the flavor: development prints everything, production only
/// records warnings and errors. Note that this sink is where driver messages
/// and stack traces belong - never the UI.
class ConsoleAppLogger implements AppLogger {
  ConsoleAppLogger(this._flavor)
    : _logger = Logger(
        filter: _FlavorFilter(_flavor),
        printer: PrettyPrinter(
          methodCount: 0,
          lineLength: 100,
          printEmojis: false,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      );

  final AppFlavor _flavor;
  final Logger _logger;

  @override
  void debug(String message, {Object? context}) =>
      _logger.d(_compose(message, context));

  @override
  void info(String message, {Object? context}) =>
      _logger.i(_compose(message, context));

  @override
  void warn(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.w(message, error: error, stackTrace: stackTrace);

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _logger.e(message, error: error, stackTrace: stackTrace);

  String _compose(String message, Object? context) =>
      context == null ? message : '$message | $context';

  /// Exposed for diagnostics screens in non-production builds.
  bool get isVerbose => !_flavor.isProduction;
}

class _FlavorFilter extends LogFilter {
  _FlavorFilter(this.flavor);

  final AppFlavor flavor;

  @override
  bool shouldLog(LogEvent event) {
    if (flavor.isProduction) {
      return event.level.index >= Level.warning.index;
    }
    return event.level.index >= Level.debug.index;
  }
}

/// Discards everything. Used in widget tests so output stays readable.
class SilentAppLogger implements AppLogger {
  const SilentAppLogger();

  @override
  void debug(String message, {Object? context}) {}

  @override
  void info(String message, {Object? context}) {}

  @override
  void warn(String message, {Object? error, StackTrace? stackTrace}) {}

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {}
}
