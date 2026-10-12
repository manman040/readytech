import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/features/auth/bloc/login_cubit.dart';
import 'package:readytech/features/auth/bloc/sign_up_cubit.dart';

import '../helpers/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repository;

  setUp(() => repository = FakeAuthRepository());
  tearDown(() => repository.dispose());

  group('LoginCubit', () {
    test('starts idle', () {
      expect(LoginCubit(repository).state.isIdle, isTrue);
    });

    test('reports progress then success', () async {
      final cubit = LoginCubit(repository);

      final states = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          predicate<SubmissionState<void>>((s) => s.isInProgress),
          predicate<SubmissionState<void>>((s) => s.isSuccess),
        ]),
      );

      await cubit.submit(email: 'adam@readytech.test', password: 'secret123');
      await states;
      await cubit.close();
    });

    test('carries the failure through so the form can show it', () async {
      repository.signInFailure = const AuthFailure.invalidCredentials();
      final cubit = LoginCubit(repository);

      await cubit.submit(email: 'adam@readytech.test', password: 'wrong');

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.failure!.message, 'Incorrect email or password.');
      await cubit.close();
    });

    test('ignores a second tap while the first is still running', () async {
      final cubit = LoginCubit(repository);

      // Both calls start before either completes, which is what a double tap
      // on a slow connection looks like.
      final first = cubit.submit(email: 'a@b.c', password: 'secret123');
      final second = cubit.submit(email: 'a@b.c', password: 'secret123');
      await Future.wait([first, second]);

      // One sign-in, not two - a duplicated request here is a duplicated job.
      expect(repository.signInCallCount, 1);
      await cubit.close();
    });

    test('clears a failure once the user starts correcting the form', () async {
      repository.signInFailure = const AuthFailure.invalidCredentials();
      final cubit = LoginCubit(repository);

      await cubit.submit(email: 'a@b.c', password: 'wrong');
      expect(cubit.state.isFailure, isTrue);

      cubit.clearFailure();
      expect(cubit.state.isIdle, isTrue);
      await cubit.close();
    });
  });

  group('SignUpCubit', () {
    test(
      'returns the email so the verification screen can name the inbox',
      () async {
        final cubit = SignUpCubit(repository);

        await cubit.submit(
          fullName: 'Adam Rahman',
          email: '  adam@readytech.test ',
          password: 'secret123',
          phone: '012-345 6789',
        );

        expect(cubit.state.isSuccess, isTrue);
        expect(cubit.state.value, 'adam@readytech.test');
        await cubit.close();
      },
    );

    test('registers a customer unless told otherwise', () async {
      final cubit = SignUpCubit(repository);

      await cubit.submit(
        fullName: 'Adam Rahman',
        email: 'adam@readytech.test',
        password: 'secret123',
      );

      expect(repository.lastSignUpRole, UserRole.customer);
      await cubit.close();
    });

    test('passes a technician registration through unchanged', () async {
      final cubit = SignUpCubit(repository);

      await cubit.submit(
        fullName: 'Hafiz Ibrahim',
        email: 'hafiz@example.com',
        password: 'secret123',
        phone: '012 345 6789',
        role: UserRole.technician,
      );

      expect(cubit.state.isSuccess, isTrue);
      expect(repository.lastSignUpRole, UserRole.technician);
      await cubit.close();
    });

    test('reports a rejected sign-up', () async {
      repository.signUpFailure = const AuthFailure(
        message: 'An account already exists for this email address.',
      );
      final cubit = SignUpCubit(repository);

      await cubit.submit(
        fullName: 'Adam Rahman',
        email: 'adam@readytech.test',
        password: 'secret123',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.failure!.message, contains('already exists'));
      await cubit.close();
    });

    test('does not submit twice', () async {
      final cubit = SignUpCubit(repository);

      await Future.wait([
        cubit.submit(
          fullName: 'Adam',
          email: 'a@b.c',
          password: 'secret123',
        ),
        cubit.submit(
          fullName: 'Adam',
          email: 'a@b.c',
          password: 'secret123',
        ),
      ]);

      expect(repository.signUpCallCount, 1);
      await cubit.close();
    });
  });

  group('SubmissionState', () {
    test('exposes field errors from a validation failure', () {
      const state = SubmissionState<void>.failure(
        ValidationFailure(
          message: 'Check the form',
          fieldErrors: {'email': 'Already taken'},
        ),
      );

      expect(state.fieldErrors['email'], 'Already taken');
    });

    test('has no field errors for other failure types', () {
      const state = SubmissionState<void>.failure(NetworkFailure());
      expect(state.fieldErrors, isEmpty);
    });
  });
}
