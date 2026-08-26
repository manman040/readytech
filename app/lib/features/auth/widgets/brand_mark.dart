import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';

/// The ReadyTech mark: a bolt in the brand square, with a live dot.
///
/// Drawn from theme colours and a Material glyph rather than shipped as an
/// image, so it stays crisp at any size, follows light and dark mode, and adds
/// no asset to the bundle. A designed logo can replace this without any call
/// site changing.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.showLiveDot = true});

  final double size;

  /// The teal dot that stands for realtime. Suppressed at small sizes where it
  /// would be noise rather than signal.
  final bool showLiveDot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: 'ReadyTech',
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(size * 0.28),
              ),
              child: Icon(
                Icons.bolt_rounded,
                size: size * 0.62,
                color: scheme.onPrimary,
              ),
            ),
            if (showLiveDot)
              Positioned(
                right: -size * 0.04,
                top: -size * 0.04,
                child: Container(
                  width: size * 0.26,
                  height: size * 0.26,
                  decoration: BoxDecoration(
                    color: context.semanticColors.live,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: scheme.surface,
                      width: size * 0.05,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The mark alongside the wordmark, used on the splash and auth screens.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.showTagline = true});

  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandMark(size: 64),
        VGap.lg,
        Text(
          'ReadyTech',
          style: theme.textTheme.headlineMedium,
        ),
        if (showTagline) ...[
          VGap.xs,
          Text(
            "Tell us what's wrong. We handle the rest.",
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
