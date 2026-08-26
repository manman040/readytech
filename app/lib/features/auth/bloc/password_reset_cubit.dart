import 'package:bloc/bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

/// Drives "forgot password" and "resend verification email".
///
/// Both are the same shape: take an email address, ask the backend to send
/// something, report that it was sent.
class PasswordResetCubit extends Cubit<SubmissionState<void>> {
  PasswordResetCubit(this._repository) : super(const SubmissionState.idle());

  final AuthRepository _repository;

  Future<void> sendResetLink(String email) async {
    if (state.isInProgress) return;
    emit(const SubmissionState.inProgress());

    final result = await _repository.sendPasswordReset(email);
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: (_) => const SubmissionState<void>.success(),
        onFailure: SubmissionState<void>.failure,
      ),
    );
  }

  Future<void> resendVerification(String email) async {
    if (state.isInProgress) return;
    emit(const SubmissionState.inProgress());

    final result = await _repository.resendVerificationEmail(email);
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: (_) => const SubmissionState<void>.success(),
        onFailure: SubmissionState<void>.failure,
      ),
    );
  }

  void reset() => emit(const SubmissionState.idle());
}
