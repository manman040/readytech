import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';

/// The standard surface for grouped content.
///
/// Separation comes from a hairline border rather than elevation. Stacked drop
/// shadows are the fastest way to make an interface look cluttered, and they
/// read poorly in dark mode where there is no light source to justify them.
class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.onTap,
    this.padding = const EdgeInsets.all(Gap.lg),
    this.isHighlighted = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  /// Draws the card in brand colour - used for the active service, which should
  /// win against everything else on the home screen.
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    final decoration = BoxDecoration(
      color: isHighlighted ? scheme.primaryContainer : scheme.surface,
      borderRadius: Radii.borderLg,
      border: Border.all(
        color: isHighlighted ? Colors.transparent : semantic.hairline,
      ),
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: content);
    }

    return Material(
      color: decoration.color,
      borderRadius: Radii.borderLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: Radii.borderLg,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: Radii.borderLg,
            border: decoration.border,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// A labelled section within a screen: a heading, an optional trailing action,
/// then content.
class AppSection extends StatelessWidget {
  const AppSection({
    required this.title,
    required this.child,
    super.key,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?action,
          ],
        ),
        VGap.md,
        child,
      ],
    );
  }
}
