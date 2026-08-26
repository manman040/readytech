import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';

/// Visual weight of a button, which should follow its importance on the screen.
///
/// A screen has at most one [AppButtonVariant.primary]. If two actions both
/// look primary, neither reads as the thing to do next.
enum AppButtonVariant { primary, secondary, text, danger }

/// The single button used across ReadyTech.
///
/// Owns the busy state so no call site has to swap a button for a spinner: the
/// control keeps its exact size, disables itself and shows progress in place.
/// That prevents both layout jumps and the double submit that creates duplicate
/// service requests.
class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isBusy = false,
    this.isFullWidth = true,
  });

  const AppButton.secondary({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isBusy = false,
    this.isFullWidth = true,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.text({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isBusy = false,
    this.isFullWidth = false,
  }) : variant = AppButtonVariant.text;

  const AppButton.danger({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.isBusy = false,
    this.isFullWidth = true,
  }) : variant = AppButtonVariant.danger;

  final String label;

  /// `null` disables the button. While [isBusy] the callback is suppressed even
  /// if one is supplied.
  final VoidCallback? onPressed;

  final AppButtonVariant variant;
  final IconData? icon;
  final bool isBusy;
  final bool isFullWidth;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = isBusy ? null : onPressed;
    final child = _Content(label: label, icon: icon, isBusy: isBusy);

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: effectiveOnPressed,
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        child: child,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: effectiveOnPressed,
        child: child,
      ),
    };

    return Semantics(
      button: true,
      enabled: effectiveOnPressed != null,
      // Screen readers should announce the wait, not just fall silent.
      label: isBusy ? '$label, in progress' : label,
      excludeSemantics: true,
      child: isFullWidth
          ? SizedBox(width: double.infinity, child: button)
          : button,
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.label,
    required this.icon,
    required this.isBusy,
  });

  final String label;
  final IconData? icon;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      // Sized to the text line height so the button does not resize.
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      );
    }

    if (icon == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20),
        HGap.sm,
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
