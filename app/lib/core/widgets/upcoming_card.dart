import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/core/widgets/app_card.dart';

/// A capability that is scheduled but not yet built.
class Upcoming {
  const Upcoming(this.icon, this.title, this.phase);

  final IconData icon;
  final String title;

  /// Which delivery phase lands it, per docs/ARCHITECTURE.md.
  final String phase;
}

/// Lists what a screen will do once the phase that builds it lands.
///
/// Shown instead of a mock-up with invented data. A placeholder that renders
/// fake technicians and fake prices is indistinguishable from a working screen
/// during a demo, and that is exactly when it misleads someone.
class UpcomingCard extends StatelessWidget {
  const UpcomingCard({
    required this.items,
    super.key,
    this.title = 'Coming next',
  });

  final String title;
  final List<Upcoming> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = context.semanticColors;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.construction_outlined,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              HGap.sm,
              Text(title, style: theme.textTheme.titleSmall),
            ],
          ),
          VGap.lg,
          for (final item in items) ...[
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: semantic.neutralContainer,
                    borderRadius: Radii.borderSm,
                  ),
                  child: Icon(
                    item.icon,
                    size: 17,
                    color: semantic.onNeutralContainer,
                  ),
                ),
                HGap.md,
                Expanded(
                  child: Text(item.title, style: theme.textTheme.bodyMedium),
                ),
                Text(item.phase, style: theme.textTheme.labelSmall),
              ],
            ),
            if (item != items.last) VGap.lg,
          ],
        ],
      ),
    );
  }
}
