import 'package:bloc/bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

/// What the last action on the verification screen was, so the UI can tell a
/// resent email apart from a completed check.
enum VerificationAction { none, resent, checked }

/// Backs the "verify your email" screen.
///
/// [checkVerification] asks the backend for a fresh token rather than trusting
/// anything local. If the address is still unconfirmed the user is told so
/// plainly - the alternative is a button that appears to do nothing.
class EmailVerificationCubit
    extends Cubit<SubmissionState<VerificationAction>> {
  EmailVerificationCubit(this._repository)
    : super(const SubmissionState.idle());

  final AuthRepository _repository;

  Future<void> resend(String email) async {
    if (state.isInProgress) return;
    emit(const SubmissionState.inProgress());

    final result = await _repository.resendVerificationEmail(email);
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: (_) => const SubmissionState<VerificationAction>.success(
          VerificationAction.resent,
        ),
        onFailure: SubmissionState<VerificationAction>.failure,
      ),
    );
  }

  /// Exchanges the refresh token and reports whether the address is confirmed.
  ///
  /// On success the repository's session stream also fires, which is what moves
  /// the router onwards - this cubit only drives the button's busy state.
  Future<void> checkVerification() async {
    if (state.isInProgress) return;
    emit(const SubmissionState.inProgress());

    final result = await _repository.refreshSession();
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: (snapshot) => switch (snapshot.status) {
          SessionStatus.signedIn =>
            const SubmissionState<VerificationAction>.success(
              VerificationAction.checked,
            ),
          SessionStatus.awaitingEmailVerification =>
            const SubmissionState<VerificationAction>.failure(
              ValidationFailure(
                message:
                    'Not verified yet. Open the link in your email, '
                    'then try again.',
              ),
            ),
          _ => const SubmissionState<VerificationAction>.failure(
            AuthFailure.sessionExpired(),
          ),
        },
        onFailure: SubmissionState<VerificationAction>.failure,
      ),
    );
  }

  void reset() => emit(const SubmissionState.idle());
}
