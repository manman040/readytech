import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/features/auth/widgets/brand_mark.dart';

/// Held while the session is restored.
///
/// There is no timer here and no minimum display time. The screen is shown for
/// exactly as long as the work takes: the router moves on the moment
/// `AuthBloc` leaves `AuthUnknown`. An artificial delay is time taken from
/// someone with a broken laptop.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLockup(showTagline: false),
            VGap.huge,
            SizedBox(
              width: 96,
              child: LinearProgressIndicator(
                minHeight: 3,
                borderRadius: BorderRadius.circular(2),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
