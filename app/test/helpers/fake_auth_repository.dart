import 'dart:async';

import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

Profile buildProfile({
  String id = 'user-1',
  String fullName = 'Adam Rahman',
  String email = 'adam@readytech.test',
  UserRole role = UserRole.customer,
  String? phone = '+60123456789',
}) {
  return Profile(
    id: id,
    fullName: fullName,
    email: email,
    phone: phone,
    role: role,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// A hand-written fake rather than a generated mock.
///
/// The auth repository's contract is small and stateful - a session stream that
/// has to interleave correctly with profile loads - and a fake that actually
/// holds that state exercises more of the bloc than a mock returning canned
/// values would.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    SessionSnapshot? initialSession,
    Profile? profile,
  }) : _session = initialSession ?? const SessionSnapshot.signedOut(),
       _profile = profile ?? buildProfile();

  final _controller = StreamController<SessionSnapshot>.broadcast();

  SessionSnapshot _session;
  Profile _profile;

  /// When set, the next [loadProfile] fails with this.
  Failure? profileFailure;

  /// When set, the next sign-in attempt fails with this.
  Failure? signInFailure;

  /// Holds [signIn] open until completed.
  ///
  /// Without this the fake returns within a microtask and the in-flight frame
  /// never renders, so a test cannot observe the busy state that a real, slow
  /// network would produce.
  Completer<void>? signInGate;

  Failure? signUpFailure;
  Failure? refreshFailure;

  int signInCallCount = 0;
  int signUpCallCount = 0;
  int signOutCallCount = 0;
  int loadProfileCallCount = 0;
  int resendCallCount = 0;

  /// The role the last sign-up asked for, so a test can prove the form's
  /// choice reached the repository unchanged.
  UserRole? lastSignUpRole;

  /// Pushes a session change, as the real repository does when Supabase
  /// reports one.
  void emitSession(SessionSnapshot snapshot) {
    _session = snapshot;
    _controller.add(snapshot);
  }

  Future<void> dispose() => _controller.close();

  @override
  Stream<SessionSnapshot> get onSessionChanged => _controller.stream;

  @override
  SessionSnapshot get currentSession => _session;

  @override
  String? get currentUserId =>
      _session.status == SessionStatus.signedIn ? _profile.id : null;

  @override
  Future<Result<SessionSnapshot>> signIn({
    required String email,
    required String password,
  }) async {
    signInCallCount += 1;
    if (signInGate != null) await signInGate!.future;
    if (signInFailure != null) return failed(signInFailure!);

    _session = SessionSnapshot(status: SessionStatus.signedIn, email: email);
    return success(_session);
  }

  @override
  Future<Result<SessionSnapshot>> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    signUpCallCount += 1;
    lastSignUpRole = role;
    if (signUpFailure != null) return failed(signUpFailure!);

    // Announced on the stream as well as returned, as the real repository
    // does: a sign-up waiting on its link is a session change the app has to
    // hear about, or it would go on showing the sign-in form.
    emitSession(
      SessionSnapshot(
        status: SessionStatus.awaitingEmailVerification,
        email: email,
      ),
    );
    return success(_session);
  }

  @override
  Future<VoidResult> signOut() async {
    signOutCallCount += 1;
    _session = const SessionSnapshot.signedOut();
    return success(null);
  }

  @override
  Future<Result<SessionSnapshot>> refreshSession() async {
    if (refreshFailure != null) return failed(refreshFailure!);
    return success(_session);
  }

  @override
  Future<VoidResult> sendPasswordReset(String email) async => success(null);

  @override
  Future<VoidResult> resendVerificationEmail(String email) async {
    resendCallCount += 1;
    return success(null);
  }

  @override
  Future<Result<Profile>> loadProfile() async {
    loadProfileCallCount += 1;
    if (profileFailure != null) return failed(profileFailure!);
    return success(_profile);
  }

  @override
  Future<Result<Profile>> updateProfile(Profile profile) async {
    _profile = profile;
    return success(profile);
  }
}
