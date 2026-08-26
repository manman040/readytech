import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/routing/app_router.dart';
import 'package:readytech/routing/routes.dart';

Profile _profile(UserRole role) => Profile(
  id: 'user-1',
  fullName: 'Adam Rahman',
  email: 'adam@readytech.test',
  role: role,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  group('redirect', () {
    group('while the session is still being restored', () {
      test('holds on the splash screen', () {
        expect(
          redirectFor(const AuthUnknown(), AppRoute.splash.path),
          isNull,
        );
      });

      test('sends every other location back to splash', () {
        // Showing the sign-in form here would flash a login screen at someone
        // who turns out to already be signed in.
        expect(
          redirectFor(const AuthUnknown(), AppRoute.customerHome.path),
          AppRoute.splash.path,
        );
        expect(
          redirectFor(const AuthUnknown(), AppRoute.signIn.path),
          AppRoute.splash.path,
        );
      });
    });

    group('when signed out', () {
      test('allows the public auth screens', () {
        for (final path in AppRoute.publicPaths) {
          expect(
            redirectFor(const AuthUnauthenticated(), path),
            isNull,
            reason: '$path should be reachable without a session',
          );
        }
      });

      test('sends everything else to sign in', () {
        expect(
          redirectFor(const AuthUnauthenticated(), AppRoute.customerHome.path),
          AppRoute.signIn.path,
        );
        expect(
          redirectFor(
            const AuthUnauthenticated(),
            AppRoute.technicianHome.path,
          ),
          AppRoute.signIn.path,
        );
        expect(
          redirectFor(const AuthUnauthenticated(), AppRoute.adminHome.path),
          AppRoute.signIn.path,
        );
      });
    });

    group('when the email is unverified', () {
      const state = AuthEmailVerificationRequired('adam@readytech.test');

      test('pins the user to the verification screen', () {
        expect(
          redirectFor(state, AppRoute.verifyEmail.path),
          isNull,
        );
        expect(
          redirectFor(state, AppRoute.customerHome.path),
          AppRoute.verifyEmail.path,
        );
      });

      test('still allows sign in, so a wrong address can be abandoned', () {
        expect(redirectFor(state, AppRoute.signIn.path), isNull);
      });
    });

    group('when the profile could not be loaded', () {
      const state = AuthProfileUnavailable(NetworkFailure());

      test(
        'shows the session error screen rather than signing the user out',
        () {
          expect(redirectFor(state, AppRoute.sessionError.path), isNull);
          expect(
            redirectFor(state, AppRoute.customerHome.path),
            AppRoute.sessionError.path,
          );
        },
      );
    });

    group('when authenticated', () {
      test('lands each role on its own home', () {
        expect(
          redirectFor(
            AuthAuthenticated(_profile(UserRole.customer)),
            AppRoute.splash.path,
          ),
          AppRoute.customerHome.path,
        );
        expect(
          redirectFor(
            AuthAuthenticated(_profile(UserRole.technician)),
            AppRoute.splash.path,
          ),
          AppRoute.technicianHome.path,
        );
        expect(
          redirectFor(
            AuthAuthenticated(_profile(UserRole.admin)),
            AppRoute.splash.path,
          ),
          AppRoute.adminHome.path,
        );
      });

      test('keeps a signed-in user off the auth screens', () {
        final state = AuthAuthenticated(_profile(UserRole.customer));
        for (final path in [
          ...AppRoute.publicPaths,
          AppRoute.verifyEmail.path,
          AppRoute.sessionError.path,
        ]) {
          expect(
            redirectFor(state, path),
            AppRoute.customerHome.path,
            reason: '$path should not be reachable with a valid session',
          );
        }
      });

      test('keeps a customer out of the technician and admin areas', () {
        final state = AuthAuthenticated(_profile(UserRole.customer));
        expect(
          redirectFor(state, AppRoute.technicianHome.path),
          AppRoute.customerHome.path,
        );
        expect(
          redirectFor(state, AppRoute.adminHome.path),
          AppRoute.customerHome.path,
        );
      });

      test('keeps a technician out of the customer and admin areas', () {
        final state = AuthAuthenticated(_profile(UserRole.technician));
        expect(
          redirectFor(state, AppRoute.customerHome.path),
          AppRoute.technicianHome.path,
        );
        expect(
          redirectFor(state, AppRoute.adminHome.path),
          AppRoute.technicianHome.path,
        );
      });

      test('allows each role to stay in its own area', () {
        expect(
          redirectFor(
            AuthAuthenticated(_profile(UserRole.customer)),
            AppRoute.customerHome.path,
          ),
          isNull,
        );
        expect(
          redirectFor(
            AuthAuthenticated(_profile(UserRole.technician)),
            AppRoute.technicianHome.path,
          ),
          isNull,
        );
        expect(
          redirectFor(
            AuthAuthenticated(_profile(UserRole.admin)),
            AppRoute.adminHome.path,
          ),
          isNull,
        );
      });
    });
  });

  group('homePathFor', () {
    test('covers every role', () {
      for (final role in UserRole.values) {
        expect(homePathFor(role), isNotEmpty);
      }
      expect(homePathFor(UserRole.customer), AppRoute.customerHome.path);
      expect(homePathFor(UserRole.technician), AppRoute.technicianHome.path);
      expect(homePathFor(UserRole.admin), AppRoute.adminHome.path);
    });
  });

  group('UserRole', () {
    test('defaults to the least privileged role for an unknown value', () {
      // A tampered or unexpected claim must never resolve to admin.
      expect(UserRole.fromWire('superuser'), UserRole.customer);
      expect(UserRole.fromWire(null), UserRole.customer);
      expect(UserRole.fromWire(''), UserRole.customer);
    });

    test('round-trips known roles', () {
      for (final role in UserRole.values) {
        expect(UserRole.fromWire(role.wireName), role);
      }
    });
  });
}
