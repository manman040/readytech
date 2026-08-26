import 'package:flutter/material.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/theme/app_spacing.dart';

/// Shorthand for the values almost every widget reaches for.
extension ThemeX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;

  /// Available width, used for the handful of layouts that adapt to tablets.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  bool get isCompactWidth => screenWidth < 600;

  /// Keyboard inset, for sheets that must stay above the keyboard.
  double get viewInsetsBottom => MediaQuery.viewInsetsOf(this).bottom;
}

/// Feedback helpers.
///
/// Centralised so that every message in the product has the same shape, and so
/// a [Failure] can only ever be shown through its user-safe message.
extension FeedbackX on BuildContext {
  void showSnack(String message, {IconData? icon}) {
    _show(message: message, icon: icon, isError: false);
  }

  /// Shows a failure. Takes the [Failure] rather than a string so no call site
  /// can accidentally interpolate `debugDetail` into the UI.
  void showFailure(Failure failure) {
    _show(
      message: failure.message,
      icon: failure is NetworkFailure
          ? Icons.wifi_off_rounded
          : Icons.error_outline_rounded,
      isError: true,
    );
  }

  void _show({
    required String message,
    required IconData? icon,
    required bool isError,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: Duration(seconds: isError ? 5 : 3),
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isError
                      ? colors.error
                      : Theme.of(this).snackBarTheme.contentTextStyle?.color,
                ),
                HGap.md,
              ],
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
