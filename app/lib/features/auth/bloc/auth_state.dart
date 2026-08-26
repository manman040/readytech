import 'package:equatable/equatable.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/models/user_role.dart';

/// The app-wide answer to "who is using this app right now".
///
/// The router reads this and nothing else to decide what a user may see. It is
/// a routing input, not an authorisation decision - the backend re-checks every
/// request through Row Level Security regardless of what this says.
sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Startup has not finished restoring a session. The splash screen holds here.
class AuthUnknown extends AuthState {
  const AuthUnknown();
}

/// No session. The user belongs in the sign-in flow.
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// The account exists but its email address is unconfirmed.
///
/// Kept distinct from [AuthAuthenticated] so an unverified account cannot reach
/// the product. Supabase will also refuse the requests, but a user should meet
/// a clear explanation rather than a wall of permission errors.
class AuthEmailVerificationRequired extends AuthState {
  const AuthEmailVerificationRequired(this.email);

  final String email;

  @override
  List<Object?> get props => [email];
}

/// Signed in, verified, and the profile has loaded.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.profile);

  final Profile profile;

  UserRole get role => profile.role;

  @override
  List<Object?> get props => [profile];
}

/// Signed in, but the profile could not be read - typically a cold start with
/// no connection. The session is intact, so the fix is a retry, not a sign-out.
class AuthProfileUnavailable extends AuthState {
  const AuthProfileUnavailable(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
