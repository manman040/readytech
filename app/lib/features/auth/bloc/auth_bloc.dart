import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/bloc/auth_event.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';

/// Owns the session for the whole app.
///
/// Exactly one instance exists, created during bootstrap and provided above the
/// router. Every screen reads the session from here rather than asking the
/// Supabase client directly, so there is a single place where "signed in" is
/// decided and a single subscription to maintain.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository repository,
    required AppLogger logger,
  }) : _repository = repository,
       _logger = logger,
       super(const AuthUnknown()) {
    on<AuthStarted>(_onStarted);
    // Session changes are serialised so a rapid sign-out/sign-in pair cannot
    // interleave two profile loads and settle on the wrong one.
    on<AuthSessionChanged>(_onSessionChanged, transformer: _sequential());
    on<AuthProfileRequested>(_onProfileRequested);
    on<AuthProfileUpdated>(_onProfileUpdated);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final AuthRepository _repository;
  final AppLogger _logger;

  StreamSubscription<SessionSnapshot>? _sessionSubscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    _sessionSubscription ??= _repository.onSessionChanged.listen(
      (snapshot) => add(AuthSessionChanged(snapshot)),
      onError: (Object error, StackTrace stackTrace) {
        _logger.error(
          'auth session stream failed',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );

    // Resolve immediately from the restored session rather than waiting for the
    // stream, so the splash screen is not held open unnecessarily.
    await _resolve(_repository.currentSession, emit);
  }

  Future<void> _onSessionChanged(
    AuthSessionChanged event,
    Emitter<AuthState> emit,
  ) => _resolve(event.snapshot, emit);

  Future<void> _onProfileRequested(
    AuthProfileRequested event,
    Emitter<AuthState> emit,
  ) => _resolve(_repository.currentSession, emit);

  void _onProfileUpdated(AuthProfileUpdated event, Emitter<AuthState> emit) {
    // Only meaningful while authenticated; ignoring it otherwise avoids
    // resurrecting a signed-out session from a stale screen.
    if (state is! AuthAuthenticated) return;
    emit(AuthAuthenticated(event.profile));
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _repository.signOut();

    // Whether or not the backend acknowledged, the local session is gone and
    // the user asked to leave. Stranding them signed in would be worse than a
    // token that expires on its own.
    result.when(
      onSuccess: (_) => emit(const AuthUnauthenticated()),
      onFailure: (failure) {
        _logger.warn('sign out did not complete cleanly: ${failure.code}');
        emit(const AuthUnauthenticated());
      },
    );
  }

  Future<void> _resolve(
    SessionSnapshot snapshot,
    Emitter<AuthState> emit,
  ) async {
    switch (snapshot.status) {
      case SessionStatus.unknown:
        emit(const AuthUnknown());

      case SessionStatus.signedOut:
        emit(const AuthUnauthenticated());

      case SessionStatus.awaitingEmailVerification:
        emit(AuthEmailVerificationRequired(snapshot.email ?? ''));

      case SessionStatus.signedIn:
        final result = await _repository.loadProfile();
        // The bloc may have been closed while the request was in flight.
        if (emit.isDone) return;

        emit(
          result.when(
            onSuccess: AuthAuthenticated.new,
            onFailure: AuthProfileUnavailable.new,
          ),
        );
    }
  }

  @override
  Future<void> close() async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    return super.close();
  }
}

/// Processes events one at a time, in order.
///
/// bloc's default `concurrent` transformer would let two overlapping session
/// changes race, and the loser would win by finishing last.
EventTransformer<E> _sequential<E>() {
  return (events, mapper) => events.asyncExpand(mapper);
}
