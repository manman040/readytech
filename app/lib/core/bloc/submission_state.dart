import 'package:equatable/equatable.dart';
import 'package:readytech/core/errors/failure.dart';

enum SubmissionStatus { idle, inProgress, success, failure }

/// The state of a one-shot action such as submitting a form.
///
/// Used by every form cubit in the app so that buttons, spinners and error
/// messages behave identically everywhere. [value] carries whatever the action
/// produced; use `void` when it produced nothing.
class SubmissionState<T> extends Equatable {
  const SubmissionState._({required this.status, this.value, this.failure});

  const SubmissionState.idle() : this._(status: SubmissionStatus.idle);

  const SubmissionState.inProgress()
    : this._(status: SubmissionStatus.inProgress);

  const SubmissionState.success([T? value])
    : this._(status: SubmissionStatus.success, value: value);

  const SubmissionState.failure(Failure failure)
    : this._(status: SubmissionStatus.failure, failure: failure);

  final SubmissionStatus status;
  final T? value;
  final Failure? failure;

  bool get isIdle => status == SubmissionStatus.idle;
  bool get isInProgress => status == SubmissionStatus.inProgress;
  bool get isSuccess => status == SubmissionStatus.success;
  bool get isFailure => status == SubmissionStatus.failure;

  /// Field-level messages, when the failure carried them. Lets a form point at
  /// the input that needs attention instead of only showing a banner.
  Map<String, String> get fieldErrors => switch (failure) {
    final ValidationFailure f => f.fieldErrors,
    _ => const {},
  };

  @override
  List<Object?> get props => [status, value, failure];
}
