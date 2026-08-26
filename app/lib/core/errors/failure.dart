import 'package:equatable/equatable.dart';

/// A problem that has already been translated into something a user may read.
///
/// Repositories return [Failure]s, never raw driver exceptions. Every message
/// carried here is safe to render: driver text, SQL and stack traces stay in
/// [debugDetail], which is only ever written to the log sink.
///
/// Implements [Exception] so a failure can also be thrown across a helper
/// boundary and be caught by the same guard that catches everything else.
sealed class Failure extends Equatable implements Exception {
  const Failure({required this.message, this.debugDetail});

  /// Safe to display to the user.
  final String message;

  /// Diagnostic context for logs. Never rendered in the UI.
  final String? debugDetail;

  /// Stable identifier for logs and analytics.
  ///
  /// Preferred over `runtimeType`, which is unreliable once a release build has
  /// been obfuscated.
  String get code;

  /// Whether retrying the same operation could plausibly succeed.
  bool get isRetryable => false;

  @override
  List<Object?> get props => [code, message, debugDetail];

  @override
  String toString() =>
      'Failure($code: $message)${debugDetail == null ? '' : ' <- $debugDetail'}';
}

/// The device has no usable connection, or the request timed out.
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Check your network and try again.',
    super.debugDetail,
  });

  @override
  String get code => 'network';

  @override
  bool get isRetryable => true;
}

/// Sign in, sign up or session refresh was rejected.
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.debugDetail});

  /// The account exists but the email address has not been confirmed.
  const AuthFailure.emailNotConfirmed({super.debugDetail})
    : super(
        message:
            'Please verify your email address before signing in. '
            'Check your inbox for the verification link.',
      );

  const AuthFailure.invalidCredentials({super.debugDetail})
    : super(message: 'Incorrect email or password.');

  const AuthFailure.sessionExpired({super.debugDetail})
    : super(message: 'Your session has expired. Please sign in again.');

  @override
  String get code => 'auth';
}

/// The caller is authenticated but not allowed to perform this action.
///
/// In practice this is what a Row Level Security rejection looks like from the
/// client side.
class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'You do not have permission to do that.',
    super.debugDetail,
  });

  @override
  String get code => 'permission';
}

/// The requested record does not exist, or is not visible to this caller.
class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'We could not find what you were looking for.',
    super.debugDetail,
  });

  @override
  String get code => 'not_found';
}

/// Input did not pass validation. [fieldErrors] lets a form highlight the
/// specific inputs that need attention.
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    this.fieldErrors = const {},
    super.debugDetail,
  });

  final Map<String, String> fieldErrors;

  @override
  String get code => 'validation';

  @override
  List<Object?> get props => [code, message, debugDetail, fieldErrors];
}

/// The operation lost a race - for example a job that another technician
/// accepted first, or a quotation that was superseded.
class ConflictFailure extends Failure {
  const ConflictFailure({
    super.message =
        'That is no longer available. Please refresh and try again.',
    super.debugDetail,
  });

  @override
  String get code => 'conflict';
}

/// The backend failed in a way the client cannot resolve.
class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Something went wrong on our side. Please try again.',
    super.debugDetail,
  });

  @override
  String get code => 'server';

  @override
  bool get isRetryable => true;
}

/// Fallback for anything not otherwise classified.
class UnknownFailure extends Failure {
  const UnknownFailure({
    super.message = 'Something went wrong. Please try again.',
    super.debugDetail,
  });

  @override
  String get code => 'unknown';

  @override
  bool get isRetryable => true;
}
