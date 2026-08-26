import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/datasources/auth_remote_datasource.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// What the app knows about the current account, independent of Supabase.
enum SessionStatus {
  /// Startup has not finished restoring a session yet.
  unknown,

  /// No valid session.
  signedOut,

  /// Signed in, but the email address has not been confirmed.
  awaitingEmailVerification,

  /// Signed in and verified.
  signedIn,
}

/// A snapshot of the session, as the rest of the app sees it.
class SessionSnapshot {
  const SessionSnapshot({
    required this.status,
    this.email,
  });

  const SessionSnapshot.unknown()
    : status = SessionStatus.unknown,
      email = null;

  const SessionSnapshot.signedOut()
    : status = SessionStatus.signedOut,
      email = null;

  final SessionStatus status;

  /// Present when an unverified account needs to be told which inbox to check.
  final String? email;
}

/// Account and profile access.
///
/// Exposed as an interface so the auth flow can be tested against a fake and so
/// the Supabase SDK stays behind the data layer.
abstract interface class AuthRepository {
  /// Session changes, including the initial restore on cold start.
  Stream<SessionSnapshot> get onSessionChanged;

  /// Session as of right now, without waiting for the stream.
  SessionSnapshot get currentSession;

  String? get currentUserId;

  Future<Result<SessionSnapshot>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  Future<Result<SessionSnapshot>> signIn({
    required String email,
    required String password,
  });

  Future<VoidResult> signOut();

  /// Re-reads the session from the backend.
  ///
  /// Needed because email confirmation happens in a browser, outside this app:
  /// the local token still says unconfirmed until it is exchanged for a new one.
  Future<Result<SessionSnapshot>> refreshSession();

  Future<VoidResult> sendPasswordReset(String email);

  Future<VoidResult> resendVerificationEmail(String email);

  /// Loads the signed-in user's profile, including the role recorded on the
  /// backend.
  Future<Result<Profile>> loadProfile();

  Future<Result<Profile>> updateProfile(Profile profile);
}

class SupabaseAuthRepository with GuardedRepository implements AuthRepository {
  SupabaseAuthRepository({
    required AuthRemoteDataSource dataSource,
    required this.logger,
  }) : _dataSource = dataSource;

  final AuthRemoteDataSource _dataSource;

  @override
  final AppLogger logger;

  @override
  Stream<SessionSnapshot> get onSessionChanged =>
      _dataSource.onAuthStateChange.map((event) => _snapshotOf(event.session));

  @override
  SessionSnapshot get currentSession => _snapshotOf(_dataSource.currentSession);

  @override
  String? get currentUserId => _dataSource.currentUser?.id;

  @override
  Future<Result<SessionSnapshot>> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) {
    return guard('auth.signUp', () async {
      final response = await _dataSource.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
        phone: phone?.trim(),
      );

      // With email confirmation enabled Supabase returns a user but no session.
      // That is the expected path, not an error - the account exists and is
      // waiting on the link in the user's inbox.
      if (response.session == null) {
        return SessionSnapshot(
          status: SessionStatus.awaitingEmailVerification,
          email: email.trim(),
        );
      }
      return _snapshotOf(response.session);
    });
  }

  @override
  Future<Result<SessionSnapshot>> signIn({
    required String email,
    required String password,
  }) {
    return guard('auth.signIn', () async {
      final response = await _dataSource.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return _snapshotOf(response.session);
    });
  }

  @override
  Future<VoidResult> signOut() => guard('auth.signOut', _dataSource.signOut);

  @override
  Future<Result<SessionSnapshot>> refreshSession() {
    return guard('auth.refreshSession', () async {
      final response = await _dataSource.refreshSession();
      return _snapshotOf(response.session);
    });
  }

  @override
  Future<VoidResult> sendPasswordReset(String email) => guard(
    'auth.sendPasswordReset',
    () => _dataSource.sendPasswordResetEmail(email.trim()),
  );

  @override
  Future<VoidResult> resendVerificationEmail(String email) => guard(
    'auth.resendVerificationEmail',
    () => _dataSource.resendVerificationEmail(email.trim()),
  );

  @override
  Future<Result<Profile>> loadProfile() {
    return guard('profile.load', () async {
      final userId = _dataSource.currentUser?.id;
      if (userId == null) {
        throw const AuthFailure.sessionExpired();
      }
      return _dataSource.fetchProfile(userId);
    });
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) {
    return guard(
      'profile.update',
      () => _dataSource.updateProfile(profile.id, profile.toUpdateJson()),
    );
  }

  SessionSnapshot _snapshotOf(sb.Session? session) {
    if (session == null) return const SessionSnapshot.signedOut();

    final user = session.user;
    // `emailConfirmedAt` is the backend's word on verification. A client must
    // never decide it is verified on its own.
    if (user.emailConfirmedAt == null) {
      return SessionSnapshot(
        status: SessionStatus.awaitingEmailVerification,
        email: user.email,
      );
    }

    return SessionSnapshot(
      status: SessionStatus.signedIn,
      email: user.email,
    );
  }
}
