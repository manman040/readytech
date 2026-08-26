import 'package:bloc/bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/helpers/validators.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

/// Drives the sign-up form.
///
/// The value carried on success is the email address, so the verification
/// screen can tell the user which inbox to open.
class SignUpCubit extends Cubit<SubmissionState<String>> {
  SignUpCubit(this._repository) : super(const SubmissionState.idle());

  final AuthRepository _repository;

  Future<void> submit({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    if (state.isInProgress) return;

    emit(const SubmissionState.inProgress());

    final result = await _repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
      // Stored in one canonical shape so the same number cannot appear as two
      // different values.
      phone: Validators.normalisePhone(phone),
    );
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: (_) => SubmissionState<String>.success(email.trim()),
        onFailure: SubmissionState<String>.failure,
      ),
    );
  }

  void clearFailure() {
    if (state.isFailure) emit(const SubmissionState.idle());
  }
}
