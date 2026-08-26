import 'package:flutter/material.dart';
import 'package:readytech/core/services/connectivity_service.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';

/// A persistent strip shown while the device has no connection.
///
/// Wrapped around the router's content so it survives navigation. It reports
/// the device's connectivity only - it never claims anything about whether a
/// service request, payment or job status went through. Those are confirmed
/// with the backend, because a queued write that looks sent is worse than an
/// obvious failure.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    required this.connectivity,
    required this.child,
    super.key,
  });

  final ConnectivityService connectivity;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<NetworkStatus>(
      stream: connectivity.onStatusChanged,
      initialData: connectivity.status,
      builder: (context, snapshot) {
        final isOffline = snapshot.data == NetworkStatus.offline;

        return Column(
          children: [
            Expanded(child: child),
            AnimatedSize(
              duration: Motion.fast,
              curve: Motion.standard,
              child: isOffline
                  ? const _Bar()
                  : const SizedBox(width: double.infinity),
            ),
          ],
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar();

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;

    return Semantics(
      liveRegion: true,
      child: Material(
        color: semantic.warningContainer,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.md,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 18,
                  color: semantic.onWarningContainer,
                ),
                HGap.md,
                Expanded(
                  child: Text(
                    'No connection. Some information may be out of date.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: semantic.onWarningContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
