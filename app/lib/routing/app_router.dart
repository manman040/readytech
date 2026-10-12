import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/features/admin/view/admin_home_page.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/features/auth/view/forgot_password_page.dart';
import 'package:readytech/features/auth/view/session_error_page.dart';
import 'package:readytech/features/auth/view/sign_in_page.dart';
import 'package:readytech/features/auth/view/sign_up_page.dart';
import 'package:readytech/features/auth/view/splash_page.dart';
import 'package:readytech/features/auth/view/verify_email_page.dart';
import 'package:readytech/features/devices/view/add_device_page.dart';
import 'package:readytech/features/devices/view/devices_page.dart';
import 'package:readytech/features/home/view/customer_home_page.dart';
import 'package:readytech/features/technician/dashboard/view/technician_home_page.dart';
import 'package:readytech/routing/routes.dart';

/// Builds the router.
///
/// All access control lives in one `GoRouter.redirect`. Scattering guards
/// across screens is how a flow ends up with one entry point that forgot to
/// check - here there is a single decision, evaluated on every navigation and
/// again whenever the session changes.
///
/// This guards *navigation*, not data. A user who reached a screen they should
/// not see would still be refused by Row Level Security on every query.
GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: AppRoute.splash.path,
    refreshListenable: _AuthRefreshListenable(authBloc.stream),
    redirect: (context, state) =>
        _redirect(authBloc.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        name: AppRoute.splash.name,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoute.signIn.path,
        name: AppRoute.signIn.name,
        builder: (_, _) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoute.signUp.path,
        name: AppRoute.signUp.name,
        builder: (_, _) => const SignUpPage(),
      ),
      GoRoute(
        path: AppRoute.forgotPassword.path,
        name: AppRoute.forgotPassword.name,
        builder: (_, _) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: AppRoute.verifyEmail.path,
        name: AppRoute.verifyEmail.name,
        builder: (_, _) => const VerifyEmailPage(),
      ),
      GoRoute(
        path: AppRoute.sessionError.path,
        name: AppRoute.sessionError.name,
        builder: (_, _) => const SessionErrorPage(),
      ),
      GoRoute(
        path: AppRoute.customerHome.path,
        name: AppRoute.customerHome.name,
        builder: (_, _) => const CustomerHomePage(),
      ),
      GoRoute(
        path: AppRoute.customerDevices.path,
        name: AppRoute.customerDevices.name,
        builder: (_, _) => const DevicesPage(),
      ),
      GoRoute(
        path: AppRoute.customerAddDevice.path,
        name: AppRoute.customerAddDevice.name,
        builder: (_, _) => const AddDevicePage(),
      ),
      GoRoute(
        path: AppRoute.technicianHome.path,
        name: AppRoute.technicianHome.name,
        builder: (_, _) => const TechnicianHomePage(),
      ),
      GoRoute(
        path: AppRoute.adminHome.path,
        name: AppRoute.adminHome.name,
        builder: (_, _) => const AdminHomePage(),
      ),
    ],
  );
}

/// Returns the path to send the user to, or `null` to allow the navigation.
///
/// Extracted and pure so the routing rules can be unit tested without building
/// a widget tree.
@visibleForTesting
String? redirectFor(AuthState authState, String location) =>
    _redirect(authState, location);

String? _redirect(AuthState authState, String location) {
  final isPublic = AppRoute.publicPaths.contains(location);
  final isSplash = location == AppRoute.splash.path;

  switch (authState) {
    // Still restoring. Hold on the splash screen; sending the user to sign-in
    // here would flash the login form at someone who is already signed in.
    case AuthUnknown():
      return isSplash ? null : AppRoute.splash.path;

    case AuthUnauthenticated():
      return isPublic ? null : AppRoute.signIn.path;

    case AuthEmailVerificationRequired():
      // Pinned to the verification screen until the address is confirmed. A
      // wrong address is abandoned with "Use a different account", which signs
      // out, so nothing else needs to be reachable - and sign-in in particular
      // must not be. The sign-up form is *pushed* on top of sign-in, so the
      // location this redirect sees right after a registration is still
      // "/sign-in"; letting that through left a new user on the form they had
      // just submitted, with no hint that an email was waiting.
      return location == AppRoute.verifyEmail.path
          ? null
          : AppRoute.verifyEmail.path;

    case AuthProfileUnavailable():
      return location == AppRoute.sessionError.path
          ? null
          : AppRoute.sessionError.path;

    case AuthAuthenticated(:final role):
      final home = homePathFor(role);
      // An authenticated user has no business on the auth screens.
      if (isPublic ||
          isSplash ||
          location == AppRoute.verifyEmail.path ||
          location == AppRoute.sessionError.path) {
        return home;
      }
      // Keep each role inside its own area.
      if (_isForeignRoleArea(location, role)) return home;
      return null;
  }
}

String homePathFor(UserRole role) => switch (role) {
  UserRole.customer => AppRoute.customerHome.path,
  UserRole.technician => AppRoute.technicianHome.path,
  UserRole.admin => AppRoute.adminHome.path,
};

bool _isForeignRoleArea(String location, UserRole role) {
  final areas = {
    AppRoute.customerHome.path: UserRole.customer,
    AppRoute.technicianHome.path: UserRole.technician,
    AppRoute.adminHome.path: UserRole.admin,
  };

  for (final entry in areas.entries) {
    if (location.startsWith(entry.key) && entry.value != role) return true;
  }
  return false;
}

/// Bridges the auth bloc's stream to the [Listenable] go_router expects.
class _AuthRefreshListenable extends ChangeNotifier {
  _AuthRefreshListenable(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
