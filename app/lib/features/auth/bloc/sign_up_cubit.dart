import 'package:bloc/bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/helpers/validators.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/auth_repository.dart';

/// Drives the sign-up form.
///
/// The value carried on success is the email address, so the verification
/// screen can tell the user which inbox to open.
class SignUpCubit extends Cubit<SubmissionState<String>> {
  SignUpCubit(this._repository) : super(const SubmissionState.idle());

  final AuthRepository _repository;

  /// [role] is what the user asked to be. The backend honours only
  /// [UserRole.technician], and even then the account starts unverified; the
  /// default is a customer because that is what most people opening the app
  /// are.
  Future<void> submit({
    required String fullName,
    required String email,
    required String password,
    UserRole role = UserRole.customer,
    String? phone,
  }) async {
    if (state.isInProgress) return;
    assert(
      role.canSelfRegister,
      'A ${role.wireName} account cannot be created from the app.',
    );

    emit(const SubmissionState.inProgress());

    final result = await _repository.signUp(
      email: email,
      password: password,
      fullName: fullName,
      role: role,
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
