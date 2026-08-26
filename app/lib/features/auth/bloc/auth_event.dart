import 'package:equatable/equatable.dart';
import 'package:readytech/data/models/profile.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Subscribe to session changes and resolve the initial state. Dispatched once,
/// during bootstrap.
class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Emitted internally when the repository reports a session change - a sign in,
/// a sign out, a token refresh, or the restore that happens on cold start.
class AuthSessionChanged extends AuthEvent {
  const AuthSessionChanged(this.snapshot);

  final SessionSnapshot snapshot;

  @override
  List<Object?> get props => [snapshot.status, snapshot.email];
}

/// Retry a profile load that failed, usually after connectivity returned.
class AuthProfileRequested extends AuthEvent {
  const AuthProfileRequested();
}

/// Apply a profile the user just edited, without a round trip.
class AuthProfileUpdated extends AuthEvent {
  const AuthProfileUpdated(this.profile);

  final Profile profile;

  @override
  List<Object?> get props => [profile];
}

class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
