import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/datasources/auth_remote_datasource.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

/// Stands in for Supabase Auth with email confirmation switched on: a sign-up
/// yields a user and no session, and a sign-in is refused until the address is
/// confirmed.
class _FakeDataSource implements AuthRemoteDataSource {
  final _events = StreamController<sb.AuthState>.broadcast();

  sb.Session? session;

  /// Thrown by the next sign-in, the way the SDK would throw it.
  Exception? signInError;

  int signInCallCount = 0;
  int refreshCallCount = 0;
  String? lastSignInEmail;

  Future<void> dispose() => _events.close();

  sb.Session sessionFor(String email, {bool confirmed = true}) => sb.Session(
    accessToken: 'access-token',
    tokenType: 'bearer',
    user: sb.User(
      id: 'user-1',
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      email: email,
      createdAt: '2026-10-05T00:00:00Z',
      emailConfirmedAt: confirmed ? '2026-10-05T00:05:00Z' : null,
    ),
  );

  @override
  sb.Session? get currentSession => session;

  @override
  sb.User? get currentUser => session?.user;

  @override
  Stream<sb.AuthState> get onAuthStateChange => _events.stream;

  @override
  Future<sb.AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required UserRole role,
    String? phone,
  }) async {
    return sb.AuthResponse(
      user: sessionFor(email, confirmed: false).user,
    );
  }

  @override
  Future<sb.AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    signInCallCount += 1;
    lastSignInEmail = email;

    final error = signInError;
    if (error != null) throw error;

    session = sessionFor(email);
    _events.add(sb.AuthState(sb.AuthChangeEvent.signedIn, session));
    return sb.AuthResponse(session: session);
  }

  @override
  Future<void> signOut() async {
    session = null;
    _events.add(const sb.AuthState(sb.AuthChangeEvent.signedOut, null));
  }

  @override
  Future<sb.AuthResponse> refreshSession() async {
    refreshCallCount += 1;
    return sb.AuthResponse(session: session);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {}

  @override
  Future<void> resendVerificationEmail(String email) async {}

  @override
  Future<Profile> fetchProfile(String userId) => throw UnimplementedError();

  @override
  Future<Profile> updateProfile(String userId, Map<String, dynamic> values) =>
      throw UnimplementedError();
}

void main() {
  late _FakeDataSource dataSource;
  late SupabaseAuthRepository repository;

  const notConfirmed = sb.AuthException(
    'Email not confirmed',
    statusCode: '400',
    code: 'email_not_confirmed',
  );

  setUp(() {
    dataSource = _FakeDataSource();
    repository = SupabaseAuthRepository(
      dataSource: dataSource,
      logger: const SilentAppLogger(),
    );
  });

  tearDown(() => dataSource.dispose());

  Future<Result<SessionSnapshot>> register() => repository.signUp(
    email: '  hafiz@example.com ',
    password: 'secret123',
    fullName: 'Hafiz Ibrahim',
    role: UserRole.technician,
    phone: '+60123456789',
  );

  SessionStatus? statusOf(Result<SessionSnapshot> result) =>
      result.valueOrNull?.status;

  group('a sign-up waiting on its confirmation link', () {
    test(
      'is announced as awaiting verification, not left as signed out',
      () async {
        final heard = <SessionSnapshot>[];
        final subscription = repository.onSessionChanged.listen(heard.add);
        addTearDown(subscription.cancel);

        final result = await register();
        await pumpEventQueue();

        expect(statusOf(result), SessionStatus.awaitingEmailVerification);
        expect(result.valueOrNull?.email, 'hafiz@example.com');

        // Supabase's own stream said nothing - there is no session to report -
        // so this is the only way the app learns the account exists.
        expect(heard, hasLength(1));
        expect(heard.single.status, SessionStatus.awaitingEmailVerification);
        expect(heard.single.email, 'hafiz@example.com');

        expect(
          repository.currentSession.status,
          SessionStatus.awaitingEmailVerification,
        );
      },
    );

    test(
      'hears "not confirmed yet" as an answer rather than an error',
      () async {
        await register();
        dataSource.signInError = notConfirmed;

        final result = await repository.refreshSession();

        expect(result.isSuccess, isTrue);
        expect(statusOf(result), SessionStatus.awaitingEmailVerification);
        // There was no token to refresh; the check was a sign-in attempt for
        // the account that was just registered.
        expect(dataSource.refreshCallCount, 0);
        expect(dataSource.signInCallCount, 1);
        expect(dataSource.lastSignInEmail, 'hafiz@example.com');
      },
    );

    test('signs in once the address has been confirmed', () async {
      await register();

      final result = await repository.refreshSession();

      expect(statusOf(result), SessionStatus.signedIn);
      expect(repository.currentSession.status, SessionStatus.signedIn);

      // The wait is over, so the next refresh is an ordinary token exchange
      // and the password is not submitted again.
      await repository.refreshSession();
      expect(dataSource.signInCallCount, 1);
      expect(dataSource.refreshCallCount, 1);
    });

    test(
      'reports a real failure during the check, and keeps waiting',
      () async {
        await register();
        dataSource.signInError = const SocketException('offline');

        final result = await repository.refreshSession();

        expect(result.failureOrNull, isA<NetworkFailure>());
        // Being offline does not mean the account went away.
        expect(
          repository.currentSession.status,
          SessionStatus.awaitingEmailVerification,
        );
      },
    );

    test('is abandoned when the user signs out', () async {
      await register();

      await repository.signOut();

      expect(repository.currentSession.status, SessionStatus.signedOut);

      // Nothing is remembered: a later refresh has no account to sign in as.
      await repository.refreshSession();
      expect(dataSource.signInCallCount, 0);
    });

    test('ends when the same person signs in from the sign-in form', () async {
      await register();

      final result = await repository.signIn(
        email: 'hafiz@example.com',
        password: 'secret123',
      );

      expect(statusOf(result), SessionStatus.signedIn);

      // Shown by losing the session without signing out: had the wait still
      // been remembered, this would read as awaiting verification again.
      dataSource.session = null;
      expect(repository.currentSession.status, SessionStatus.signedOut);
    });
  });

  group('with an existing session', () {
    test('refreshes the token and never submits a password', () async {
      dataSource.session = dataSource.sessionFor('adam@readytech.test');

      final result = await repository.refreshSession();

      expect(statusOf(result), SessionStatus.signedIn);
      expect(dataSource.refreshCallCount, 1);
      expect(dataSource.signInCallCount, 0);
    });

    test('relays what the backend reports on the session stream', () async {
      final heard = <SessionSnapshot>[];
      final subscription = repository.onSessionChanged.listen(heard.add);
      addTearDown(subscription.cancel);

      await repository.signIn(
        email: 'adam@readytech.test',
        password: 'secret123',
      );
      await repository.signOut();
      await pumpEventQueue();

      expect(
        heard.map((snapshot) => snapshot.status),
        [SessionStatus.signedIn, SessionStatus.signedOut],
      );
    });
  });
}
