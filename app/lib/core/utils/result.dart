import 'package:fpdart/fpdart.dart';
import 'package:readytech/core/errors/failure.dart';

/// The return type of every repository method.
///
/// Repositories never throw and never return `null` to signal a problem - a
/// caller must decide what to do with a [Failure] before it can reach the
/// value, which is what keeps error handling from being forgotten.
typedef Result<T> = Either<Failure, T>;

/// A [Result] that carries no value, only success or failure.
typedef VoidResult = Result<void>;

/// Wraps [value] as a successful result.
Result<T> success<T>(T value) => Right<Failure, T>(value);

/// Wraps [failure] as a failed result.
Result<T> failed<T>(Failure failure) => Left<Failure, T>(failure);

extension ResultX<T> on Result<T> {
  bool get isSuccess => isRight();
  bool get isFailure => isLeft();

  /// The value, or `null` when this result is a failure.
  T? get valueOrNull => switch (this) {
    Right(:final value) => value,
    Left() => null,
  };

  /// The failure, or `null` when this result succeeded.
  Failure? get failureOrNull => switch (this) {
    Left(:final value) => value,
    Right() => null,
  };

  /// Runs [onSuccess] or [onFailure] depending on the outcome.
  ///
  /// Prefer this over checking [isSuccess] and then reading [valueOrNull],
  /// which loses the compiler's guarantee that both cases were handled.
  R when<R>({
    required R Function(T value) onSuccess,
    required R Function(Failure failure) onFailure,
  }) => switch (this) {
    Right(:final value) => onSuccess(value),
    Left(:final value) => onFailure(value),
  };
}
