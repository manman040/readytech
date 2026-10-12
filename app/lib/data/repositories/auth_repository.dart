import 'dart:async';

import 'package:readytech/core/errors/error_mapper.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/datasources/auth_remote_datasource.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/base_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// What the app knows about the current account, independent of Supabase.
enum SessionStatus {
  /// Startup has not finished restoring a session yet.
  unknown,

  /// No valid session.
  signedOut,

  /// The account exists but its email address has not been confirmed.
  ///
  /// Right after a sign-up there is usually no session at all behind this -
  /// Supabase withholds one until the link is opened - so it means "known and
  /// waiting", not "signed in".
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
  /// Session changes, including the initial restore on cold start and a
  /// sign-up that is left waiting on its confirmation link.
  Stream<SessionSnapshot> get onSessionChanged;

  /// Session as of right now, without waiting for the stream.
  SessionSnapshot get currentSession;

  String? get currentUserId;

  /// Creates an account. [role] is a request, not a grant: the backend honours
  /// only [UserRole.technician], and even then the technician starts
  /// unverified. See [UserRole.canSelfRegister].
  ///
  /// When the account needs its email confirmed, the resulting
  /// [SessionStatus.awaitingEmailVerification] is also reported on
  /// [onSessionChanged], which is what moves the app to the verification
  /// screen.
  Future<Result<SessionSnapshot>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  });

  Future<Result<SessionSnapshot>> signIn({
    required String email,
    required String password,
  });

  Future<VoidResult> signOut();

  /// Re-reads the session from the backend.
  ///
  /// Needed because email confirmation happens in a browser, outside this app.
  /// For an existing session the token is exchanged for a new one. For an
  /// account registered moments ago, which has no token to exchange, this
  /// instead finds out whether the link has been opened and signs the user in
  /// if it has.
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

  /// Set between a sign-up that produced no session and the moment that
  /// account is confirmed or abandoned. See [_PendingVerification].
  _PendingVerification? _pending;

  /// Session changes this repository originates itself.
  ///
  /// Supabase's own stream only speaks when a session appears or disappears,
  /// and a sign-up waiting on its confirmation link is neither. Lives as long
  /// as the repository, which is the lifetime of the app.
  final _localChanges = StreamController<SessionSnapshot>.broadcast();

  @override
  Stream<SessionSnapshot> get onSessionChanged {
    // Two sources merged by hand: not worth a dependency, and the lifetime is
    // simply that of whoever is listening.
    late final StreamController<SessionSnapshot> merged;
    StreamSubscription<SessionSnapshot>? fromBackend;
    StreamSubscription<SessionSnapshot>? fromLocal;

    merged = StreamController<SessionSnapshot>(
      onListen: () {
        fromBackend = _dataSource.onAuthStateChange
            .map(_onBackendSession)
            .listen(merged.add, onError: merged.addError);
        fromLocal = _localChanges.stream.listen(merged.add);
      },
      onCancel: () async {
        await fromBackend?.cancel();
        await fromLocal?.cancel();
      },
    );
    return merged.stream;
  }

  @override
  SessionSnapshot get currentSession => _snapshotOf(_dataSource.currentSession);

  @override
  String? get currentUserId => _dataSource.currentUser?.id;

  @override
  Future<Result<SessionSnapshot>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) {
    assert(
      role.canSelfRegister,
      'A ${role.wireName} account cannot be created from the app.',
    );
    return guard('auth.signUp', () async {
      final response = await _dataSource.signUp(
        email: email.trim(),
        password: password,
        fullName: fullName.trim(),
        role: role,
        phone: phone?.trim(),
      );

      // With email confirmation enabled Supabase returns a user but no session.
      // That is the expected path, not an error - the account exists and is
      // waiting on the link in the user's inbox. Supabase's own stream stays
      // silent about it, so it is announced here; otherwise the rest of the
      // app would still believe nobody is there and show the sign-in form.
      if (response.session == null) {
        final pending = _PendingVerification(
          email: email.trim(),
          password: password,
        );
        _pending = pending;
        _localChanges.add(pending.snapshot);
        return pending.snapshot;
      }

      _pending = null;
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
      if (response.session != null) _pending = null;
      return _snapshotOf(response.session);
    });
  }

  @override
  Future<VoidResult> signOut() {
    // Dropped first, so the signed-out event that follows is reported as
    // signed out rather than as an account still waiting on its link.
    _pending = null;
    return guard('auth.signOut', _dataSource.signOut);
  }

  @override
  Future<Result<SessionSnapshot>> refreshSession() {
    return guard('auth.refreshSession', () async {
      final pending = _pending;
      if (pending != null && _dataSource.currentSession == null) {
        return _checkPendingVerification(pending);
      }

      final response = await _dataSource.refreshSession();
      return _snapshotOf(response.session);
    });
  }

  /// Finds out whether a freshly registered account has opened its link.
  ///
  /// There is no token to refresh - the account was created without a session -
  /// so the one question the backend will answer is "may this person sign in?".
  /// Yes means the address is confirmed, and they are now signed in. A refusal
  /// because the address is unconfirmed is the expected "not yet" and is
  /// returned as such; any other failure is a real one and is left to the
  /// guard.
  Future<SessionSnapshot> _checkPendingVerification(
    _PendingVerification pending,
  ) async {
    try {
      final response = await _dataSource.signInWithPassword(
        email: pending.email,
        password: pending.password,
      );
      if (response.session != null) _pending = null;
      return _snapshotOf(response.session);
    } on sb.AuthException catch (error) {
      if (ErrorMapper.isEmailNotConfirmed(error)) return pending.snapshot;
      rethrow;
    }
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

  SessionSnapshot _onBackendSession(sb.AuthState event) {
    // A real session supersedes any wait: whoever this is, they are in.
    if (event.session != null) _pending = null;
    return _snapshotOf(event.session);
  }

  SessionSnapshot _snapshotOf(sb.Session? session) {
    if (session == null) {
      // No tokens, but an account may still be waiting on its link.
      return _pending?.snapshot ?? const SessionSnapshot.signedOut();
    }

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

/// An account created moments ago that has not confirmed its address.
///
/// The password is held because nothing else can answer "has the link been
/// opened yet?": there is no session, so there is no token to refresh. It
/// exists only in memory, only until the account is confirmed, abandoned or the
/// app is closed, and is never written to storage or to a log - [toString]
/// leaves it out so an accidental interpolation cannot leak it.
class _PendingVerification {
  const _PendingVerification({required this.email, required this.password});

  final String email;
  final String password;

  SessionSnapshot get snapshot => SessionSnapshot(
    status: SessionStatus.awaitingEmailVerification,
    email: email,
  );

  @override
  String toString() => '_PendingVerification($email)';
}
