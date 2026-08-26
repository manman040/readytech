import 'package:flutter/material.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/core/widgets/app_button.dart';

/// Shown when a list or screen has nothing in it yet.
///
/// An empty state always says what the user can do next. "No devices" is a dead
/// end; "Add a device to keep its service history in one place" is an offer.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.title,
    required this.message,
    super.key,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _CentredMessage(
      icon: icon,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      iconBackground: context.semanticColors.neutralContainer,
      title: title,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

/// Shown when an operation failed.
///
/// Renders [Failure.message] only. The driver text in [Failure.debugDetail]
/// stays in the logs; a stack trace on screen tells the user nothing and tells
/// an attacker something.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    required this.failure,
    super.key,
    this.onRetry,
    this.title = 'Something went wrong',
  });

  final Failure failure;
  final VoidCallback? onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isOffline = failure is NetworkFailure;

    return _CentredMessage(
      icon: isOffline ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
      iconColor: scheme.error,
      iconBackground: scheme.errorContainer,
      title: isOffline ? 'You are offline' : title,
      message: failure.message,
      // Only offer a retry for something a retry could actually fix.
      actionLabel: onRetry != null && failure.isRetryable ? 'Try again' : null,
      onAction: onRetry,
    );
  }
}

class _CentredMessage extends StatelessWidget {
  const _CentredMessage({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: iconColor),
            ),
            VGap.xl,
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            VGap.sm,
            Text(
              message,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              VGap.xl,
              AppButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                isFullWidth: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full-screen progress. Used only where there is no meaningful skeleton to
/// show - a skeleton communicates the shape of what is coming and is preferred.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (label != null) ...[
            VGap.lg,
            Text(label!, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
