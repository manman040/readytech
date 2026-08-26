import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:readytech/core/errors/error_mapper.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ErrorMapper', () {
    test('never lets driver detail reach the user-facing message', () {
      const leakyDetail = 'relation "public.service_requests" does not exist';
      final failure = ErrorMapper.map(
        const PostgrestException(message: leakyDetail, code: '42P01'),
      );

      expect(failure.message, isNot(contains('relation')));
      expect(failure.message, isNot(contains('public.')));
      // The detail is kept, but only for the log sink.
      expect(failure.debugDetail, contains(leakyDetail));
    });

    group('auth errors', () {
      test('maps invalid credentials', () {
        final failure = ErrorMapper.map(
          const AuthException('Invalid login', code: 'invalid_credentials'),
        );
        expect(failure, isA<AuthFailure>());
        expect(failure.message, 'Incorrect email or password.');
      });

      test('maps an unconfirmed email to actionable guidance', () {
        final failure = ErrorMapper.map(
          const AuthException(
            'Email not confirmed',
            code: 'email_not_confirmed',
          ),
        );
        expect(failure, isA<AuthFailure>());
        expect(failure.message, contains('verify your email'));
      });

      test('maps a duplicate account', () {
        final failure = ErrorMapper.map(
          const AuthException('exists', code: 'user_already_exists'),
        );
        expect(failure.message, contains('already exists'));
      });

      test('maps a rate limit to something a user can act on', () {
        final failure = ErrorMapper.map(
          const AuthException('slow down', code: 'over_email_send_rate_limit'),
        );
        expect(failure.message, contains('Too many attempts'));
      });

      test(
        'treats a transport failure as a network problem, not an auth one',
        () {
          final failure = ErrorMapper.map(AuthRetryableFetchException());
          expect(failure, isA<NetworkFailure>());
          expect(failure.isRetryable, isTrue);
        },
      );

      test('treats a missing session as an expired one', () {
        final failure = ErrorMapper.map(AuthSessionMissingException());
        expect(failure, isA<AuthFailure>());
        expect(failure.message, contains('session has expired'));
      });
    });

    group('postgres errors', () {
      test('surfaces our own RT-class messages verbatim', () {
        // The backend raises these deliberately, with text written for a user.
        const message =
            'Repair cannot start until the customer approves a quotation.';
        final failure = ErrorMapper.map(
          const PostgrestException(message: message, code: 'RT400'),
        );

        expect(failure, isA<ValidationFailure>());
        expect(failure.message, message);
      });

      test('maps each RT class to its failure type', () {
        expect(
          ErrorMapper.map(
            const PostgrestException(message: 'x', code: 'RT403'),
          ),
          isA<PermissionFailure>(),
        );
        expect(
          ErrorMapper.map(
            const PostgrestException(message: 'x', code: 'RT404'),
          ),
          isA<NotFoundFailure>(),
        );
        expect(
          ErrorMapper.map(
            const PostgrestException(message: 'x', code: 'RT409'),
          ),
          isA<ConflictFailure>(),
        );
      });

      test('maps a row level security rejection to a permission failure', () {
        final failure = ErrorMapper.map(
          const PostgrestException(message: 'permission denied', code: '42501'),
        );
        expect(failure, isA<PermissionFailure>());
      });

      test('maps an empty single() result to not found', () {
        final failure = ErrorMapper.map(
          const PostgrestException(message: 'no rows', code: 'PGRST116'),
        );
        expect(failure, isA<NotFoundFailure>());
      });

      test('maps a unique violation to a conflict', () {
        final failure = ErrorMapper.map(
          const PostgrestException(message: 'duplicate key', code: '23505'),
        );
        expect(failure, isA<ConflictFailure>());
      });

      test('falls back to a server failure for anything unrecognised', () {
        final failure = ErrorMapper.map(
          const PostgrestException(message: 'boom', code: 'XX000'),
        );
        expect(failure, isA<ServerFailure>());
      });
    });

    group('edge function errors', () {
      test('surfaces the message an Edge Function meant for the user', () {
        final failure = ErrorMapper.map(
          const FunctionsHttpException(
            status: 409,
            details: {
              'error': {'message': 'This job has already been taken.'},
            },
          ),
        );

        expect(failure, isA<ConflictFailure>());
        expect(failure.message, 'This job has already been taken.');
      });

      test('falls back to a generic message when none was provided', () {
        final failure = ErrorMapper.map(
          const FunctionsHttpException(status: 409, details: {'trace': 'abc'}),
        );
        expect(failure, isA<ConflictFailure>());
        expect(failure.message, contains('no longer available'));
      });

      test('treats a fetch failure as a network problem', () {
        final failure = ErrorMapper.map(const FunctionsFetchException());
        expect(failure, isA<NetworkFailure>());
      });
    });

    group('transport errors', () {
      test(
        'maps socket, timeout and client exceptions to network failures',
        () {
          for (final error in <Object>[
            const SocketException('no route to host'),
            TimeoutException('timed out'),
            ClientException('connection closed'),
          ]) {
            expect(
              ErrorMapper.map(error),
              isA<NetworkFailure>(),
              reason: '$error should be a network failure',
            );
          }
        },
      );
    });

    test('passes an existing Failure through unchanged', () {
      const original = ConflictFailure(message: 'already taken');
      expect(ErrorMapper.map(original), same(original));
    });

    test('maps anything else to an unknown, retryable failure', () {
      final failure = ErrorMapper.map(StateError('unexpected'));
      expect(failure, isA<UnknownFailure>());
      expect(failure.isRetryable, isTrue);
    });

    test('every failure carries a stable code for logging', () {
      final failures = <Failure>[
        const NetworkFailure(),
        const AuthFailure(message: 'x'),
        const PermissionFailure(),
        const NotFoundFailure(),
        const ValidationFailure(message: 'x'),
        const ConflictFailure(),
        const ServerFailure(),
        const UnknownFailure(),
      ];

      final codes = failures.map((f) => f.code).toList();
      expect(
        codes.toSet().length,
        codes.length,
        reason: 'codes must be unique',
      );
      expect(codes.every((code) => code.isNotEmpty), isTrue);
    });
  });
}
