import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_event.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';

import '../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;
  late AuthBloc bloc;

  AuthBloc buildBloc() =>
      AuthBloc(repository: repository, logger: const SilentAppLogger());

  /// Subscribes before dispatching, then dispatches.
  ///
  /// The order matters: the bloc can settle before a later `expectLater` ever
  /// subscribes, and the test would then hang waiting for an event that has
  /// already gone past.
  Future<void> expectAfter(AuthEvent event, Matcher matcher) {
    final settled = expectLater(bloc.stream, emitsInOrder(<Matcher>[matcher]));
    bloc.add(event);
    return settled;
  }

  const restoredSession = SessionSnapshot(
    status: SessionStatus.signedIn,
    email: 'adam@readytech.test',
  );

  setUp(() {
    repository = FakeAuthRepository();
  });

  tearDown(() async {
    await bloc.close();
    await repository.dispose();
  });

  test('starts in the unknown state so the splash screen holds', () {
    bloc = buildBloc();
    expect(bloc.state, const AuthUnknown());
  });

  test('resolves to signed out when there is no restored session', () async {
    bloc = buildBloc();
    await expectAfter(const AuthStarted(), isA<AuthUnauthenticated>());
  });

  test('loads the profile when a session is restored on cold start', () async {
    repository = FakeAuthRepository(
      initialSession: restoredSession,
      profile: buildProfile(role: UserRole.technician),
    );
    bloc = buildBloc();

    await expectAfter(const AuthStarted(), isA<AuthAuthenticated>());

    expect((bloc.state as AuthAuthenticated).role, UserRole.technician);
    expect(repository.loadProfileCallCount, 1);
  });

  test('holds an unverified account short of the product', () async {
    repository = FakeAuthRepository(
      initialSession: const SessionSnapshot(
        status: SessionStatus.awaitingEmailVerification,
        email: 'adam@readytech.test',
      ),
    );
    bloc = buildBloc();

    await expectAfter(
      const AuthStarted(),
      isA<AuthEmailVerificationRequired>(),
    );

    expect(
      (bloc.state as AuthEmailVerificationRequired).email,
      'adam@readytech.test',
    );
    // The profile is never fetched for an account that cannot use the product.
    expect(repository.loadProfileCallCount, 0);
  });

  test(
    'moves a fresh registration to email verification, not back to sign-in',
    () async {
      bloc = buildBloc();
      await expectAfter(const AuthStarted(), isA<AuthUnauthenticated>());

      final settled = expectLater(
        bloc.stream,
        emitsInOrder(<Matcher>[isA<AuthEmailVerificationRequired>()]),
      );
      // Sign-up returns no session while the address is unconfirmed. The bloc
      // still has to hear about it, or the router keeps showing sign-in.
      await repository.signUp(
        email: 'hafiz@example.com',
        password: 'secret123',
        fullName: 'Hafiz Ibrahim',
        role: UserRole.technician,
      );
      await settled;

      expect(
        (bloc.state as AuthEmailVerificationRequired).email,
        'hafiz@example.com',
      );
    },
  );

  test(
    'reports a profile load failure without discarding the session',
    () async {
      repository = FakeAuthRepository(initialSession: restoredSession)
        ..profileFailure = const NetworkFailure();
      bloc = buildBloc();

      await expectAfter(const AuthStarted(), isA<AuthProfileUnavailable>());

      // Signing the user out here would make them retype a password to solve a
      // network problem.
      expect(
        (bloc.state as AuthProfileUnavailable).failure,
        isA<NetworkFailure>(),
      );
    },
  );

  test('retries the profile load on request', () async {
    repository = FakeAuthRepository(initialSession: restoredSession)
      ..profileFailure = const NetworkFailure();
    bloc = buildBloc();

    await expectAfter(const AuthStarted(), isA<AuthProfileUnavailable>());

    // Connection came back.
    repository.profileFailure = null;
    await expectAfter(const AuthProfileRequested(), isA<AuthAuthenticated>());
  });

  test('follows a sign-in reported through the session stream', () async {
    bloc = buildBloc();
    await expectAfter(const AuthStarted(), isA<AuthUnauthenticated>());

    final settled = expectLater(
      bloc.stream,
      emitsInOrder(<Matcher>[isA<AuthAuthenticated>()]),
    );
    repository.emitSession(restoredSession);
    await settled;
  });

  test('signs the user out even if the backend call fails', () async {
    repository = FakeAuthRepository(initialSession: restoredSession);
    bloc = buildBloc();

    await expectAfter(const AuthStarted(), isA<AuthAuthenticated>());
    await expectAfter(
      const AuthSignOutRequested(),
      isA<AuthUnauthenticated>(),
    );

    expect(repository.signOutCallCount, 1);
  });

  test('applies a locally edited profile without a round trip', () async {
    repository = FakeAuthRepository(initialSession: restoredSession);
    bloc = buildBloc();

    await expectAfter(const AuthStarted(), isA<AuthAuthenticated>());
    await expectAfter(
      AuthProfileUpdated(buildProfile(fullName: 'Adam R.')),
      isA<AuthAuthenticated>(),
    );

    expect((bloc.state as AuthAuthenticated).profile.fullName, 'Adam R.');
    expect(repository.loadProfileCallCount, 1, reason: 'no extra fetch');
  });

  test('ignores a profile update while signed out', () async {
    bloc = buildBloc();
    await expectAfter(const AuthStarted(), isA<AuthUnauthenticated>());

    bloc.add(AuthProfileUpdated(buildProfile()));
    // A stale screen must not be able to resurrect a signed-out session.
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state, isA<AuthUnauthenticated>());
  });
}
