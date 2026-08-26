import 'package:readytech/core/errors/error_mapper.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/utils/result.dart';

/// Shared plumbing for repositories.
///
/// Every backend call goes through [guard], which is the one place an exception
/// becomes a [Result]. That guarantees two things the app depends on: a
/// repository never throws at its caller, and every failure is logged with its
/// diagnostic detail before the user-safe message is handed to the UI.
mixin GuardedRepository {
  AppLogger get logger;

  /// Runs [body], converting any thrown object into a failed [Result].
  ///
  /// [operation] names the call site so a log line is useful on its own -
  /// "profile.load failed" rather than an anonymous stack trace.
  Future<Result<T>> guard<T>(
    String operation,
    Future<T> Function() body,
  ) async {
    try {
      return success(await body());
    }
    // Deliberately unbounded: the whole point of the guard is that nothing
    // escapes it. Narrowing this would let an unanticipated driver exception
    // reach the UI as a crash.
    // ignore: avoid_catches_without_on_clauses
    catch (error, stackTrace) {
      final failure = ErrorMapper.map(error, stackTrace);
      logger.error(
        '$operation failed: ${failure.code}',
        error: failure.debugDetail ?? error,
        stackTrace: stackTrace,
      );
      return failed<T>(failure);
    }
  }
}
