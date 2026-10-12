import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:readytech/core/errors/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Application-defined SQLSTATE codes raised by our own Postgres functions and
/// triggers.
///
/// Postgres reserves the standard error classes; the "RT" class is ours.
/// Raising one of these is a promise by the backend that the accompanying
/// MESSAGE was written for a user to read, so [ErrorMapper] is allowed to
/// surface it verbatim. Every other database error is replaced with a generic
/// message so that schema details never leak into the UI.
abstract final class AppSqlState {
  /// Input failed a domain rule. Message is user-safe.
  static const validation = 'RT400';

  /// Caller is not permitted to perform this action. Message is user-safe.
  static const forbidden = 'RT403';

  /// Target row does not exist or is not visible. Message is user-safe.
  static const notFound = 'RT404';

  /// Lost a race, or an illegal state transition was attempted.
  /// Message is user-safe.
  static const conflict = 'RT409';

  static const Set<String> all = {validation, forbidden, notFound, conflict};
}

/// Translates every exception the data layer can throw into a [Failure].
///
/// This is the single place where backend vocabulary becomes user vocabulary.
/// Repositories must not construct a [Failure] from a raw exception themselves.
abstract final class ErrorMapper {
  static Failure map(Object error, [StackTrace? stackTrace]) {
    final detail = error.toString();

    return switch (error) {
      final Failure failure => failure,
      final AuthException e => _mapAuth(e, detail),
      final PostgrestException e => _mapPostgrest(e, detail),
      final StorageException e => _mapStorage(e, detail),
      FunctionsFetchException() => NetworkFailure(debugDetail: detail),
      final FunctionException e => _mapFunction(e, detail),
      SocketException() ||
      TimeoutException() ||
      ClientException() => NetworkFailure(debugDetail: detail),
      FormatException() => ServerFailure(debugDetail: detail),
      _ => UnknownFailure(debugDetail: detail),
    };
  }

  static const _emailNotConfirmedCodes = {
    'email_not_confirmed',
    'provider_email_needs_verification',
  };

  /// Whether [error] is the backend refusing a sign-in because the address has
  /// not been confirmed yet.
  ///
  /// Exposed because that refusal is sometimes the answer to a question rather
  /// than a failure: checking whether a freshly registered account has opened
  /// its link is done by asking to sign in, and "not confirmed" is then simply
  /// "not yet". Keeping the codes here means that caller does not need to know
  /// the backend's vocabulary.
  static bool isEmailNotConfirmed(Object error) =>
      error is AuthException && _emailNotConfirmedCodes.contains(error.code);

  static Failure _mapAuth(AuthException error, String detail) {
    if (error is AuthSessionMissingException) {
      return AuthFailure.sessionExpired(debugDetail: detail);
    }
    if (error is AuthRetryableFetchException) {
      return NetworkFailure(debugDetail: detail);
    }
    if (isEmailNotConfirmed(error)) {
      return AuthFailure.emailNotConfirmed(debugDetail: detail);
    }

    return switch (error.code) {
      'invalid_credentials' => AuthFailure.invalidCredentials(
        debugDetail: detail,
      ),
      'session_expired' ||
      'session_not_found' ||
      'bad_jwt' => AuthFailure.sessionExpired(debugDetail: detail),
      'user_already_exists' || 'email_exists' => AuthFailure(
        message: 'An account already exists for this email address.',
        debugDetail: detail,
      ),
      'weak_password' => AuthFailure(
        message: 'Please choose a stronger password.',
        debugDetail: detail,
      ),
      'over_email_send_rate_limit' || 'over_request_rate_limit' => AuthFailure(
        message: 'Too many attempts. Please wait a moment and try again.',
        debugDetail: detail,
      ),
      'user_banned' => AuthFailure(
        message: 'This account has been suspended. Please contact support.',
        debugDetail: detail,
      ),
      'signup_disabled' => AuthFailure(
        message: 'New sign ups are temporarily unavailable.',
        debugDetail: detail,
      ),
      'validation_failed' => ValidationFailure(
        message: 'Please check the details you entered.',
        debugDetail: detail,
      ),
      _ => AuthFailure(
        message: 'We could not complete that request. Please try again.',
        debugDetail: detail,
      ),
    };
  }

  static Failure _mapPostgrest(PostgrestException error, String detail) {
    final code = error.code;

    // Our own functions raise messages that were written to be read by users.
    if (code != null && AppSqlState.all.contains(code)) {
      return switch (code) {
        AppSqlState.validation => ValidationFailure(
          message: error.message,
          debugDetail: detail,
        ),
        AppSqlState.forbidden => PermissionFailure(
          message: error.message,
          debugDetail: detail,
        ),
        AppSqlState.notFound => NotFoundFailure(
          message: error.message,
          debugDetail: detail,
        ),
        _ => ConflictFailure(message: error.message, debugDetail: detail),
      };
    }

    return switch (code) {
      // PostgREST: .single() matched zero rows.
      'PGRST116' => NotFoundFailure(debugDetail: detail),
      // PostgREST: JWT expired or invalid.
      'PGRST301' || '401' => AuthFailure.sessionExpired(debugDetail: detail),
      // Row Level Security rejected the statement.
      '42501' || '403' => PermissionFailure(debugDetail: detail),
      // unique_violation
      '23505' => ConflictFailure(
        message: 'That record already exists.',
        debugDetail: detail,
      ),
      // foreign_key_violation
      '23503' => ValidationFailure(
        message: 'That reference is no longer valid. Please refresh.',
        debugDetail: detail,
      ),
      // not_null_violation / check_violation
      '23502' || '23514' => ValidationFailure(
        message: 'Some required information is missing or invalid.',
        debugDetail: detail,
      ),
      _ => ServerFailure(debugDetail: detail),
    };
  }

  static Failure _mapStorage(StorageException error, String detail) {
    return switch (error.statusCode) {
      '401' => AuthFailure.sessionExpired(debugDetail: detail),
      '403' => PermissionFailure(
        message: 'You do not have permission to access that file.',
        debugDetail: detail,
      ),
      '404' => NotFoundFailure(
        message: 'That file is no longer available.',
        debugDetail: detail,
      ),
      '413' => ValidationFailure(
        message: 'That file is too large. Please choose a smaller one.',
        debugDetail: detail,
      ),
      _ => ServerFailure(debugDetail: detail),
    };
  }

  static Failure _mapFunction(FunctionException error, String detail) {
    return switch (error.status) {
      400 => ValidationFailure(
        message:
            _functionMessage(error) ?? 'Please check the details you entered.',
        debugDetail: detail,
      ),
      401 => AuthFailure.sessionExpired(debugDetail: detail),
      403 => PermissionFailure(debugDetail: detail),
      404 => NotFoundFailure(debugDetail: detail),
      409 => ConflictFailure(
        message:
            _functionMessage(error) ??
            'That is no longer available. Please refresh and try again.',
        debugDetail: detail,
      ),
      429 => ServerFailure(
        message: 'Too many requests. Please wait a moment and try again.',
        debugDetail: detail,
      ),
      _ => ServerFailure(debugDetail: detail),
    };
  }

  /// Edge Functions return a JSON body shaped like
  /// `{"error": {"message": "..."}}` for problems the user is meant to see.
  /// Anything else stays in the logs.
  static String? _functionMessage(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final nested = details['error'];
      if (nested is Map && nested['message'] is String) {
        return nested['message'] as String;
      }
      if (details['message'] is String) {
        return details['message'] as String;
      }
    }
    return null;
  }
}
