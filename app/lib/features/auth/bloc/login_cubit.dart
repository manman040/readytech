import 'package:bloc/bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

/// Drives the sign-in form.
///
/// On success it emits and stops. It does not navigate: the session change
/// reaches `AuthBloc` through the repository stream, and the router reacts to
/// that. Keeping navigation off this path means a session restored on cold
/// start and a session created by this form take the identical route.
class LoginCubit extends Cubit<SubmissionState<void>> {
  LoginCubit(this._repository) : super(const SubmissionState.idle());

  final AuthRepository _repository;

  Future<void> submit({
    required String email,
    required String password,
  }) async {
    // Ignore a second tap while the first is still running - otherwise a slow
    // network turns one sign-in into two.
    if (state.isInProgress) return;

    emit(const SubmissionState.inProgress());

    final result = await _repository.signIn(email: email, password: password);
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: (_) => const SubmissionState<void>.success(),
        onFailure: SubmissionState<void>.failure,
      ),
    );
  }

  /// Clears a failure so the error banner disappears once the user starts
  /// correcting the form.
  void clearFailure() {
    if (state.isFailure) emit(const SubmissionState.idle());
  }
}
