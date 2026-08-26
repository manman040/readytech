import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';

/// A shimmering placeholder block.
///
/// One [AnimationController] drives every descendant [Skeleton] through an
/// inherited listenable, rather than each block running its own ticker. A list
/// of twenty skeleton rows should cost one animation, not twenty.
class SkeletonGroup extends StatefulWidget {
  const SkeletonGroup({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonGroup> createState() => _SkeletonGroupState();

  static Animation<double>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_SkeletonScope>()
        ?.animation;
  }
}

class _SkeletonGroupState extends State<SkeletonGroup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _animation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SkeletonScope(animation: _animation, child: widget.child);
  }
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_SkeletonScope oldWidget) =>
      oldWidget.animation != animation;
}

/// A single placeholder block, sized to the content it stands in for.
class Skeleton extends StatelessWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = Radii.borderSm,
  });

  /// A placeholder shaped like a line of text.
  const Skeleton.text({super.key, this.width, this.height = 14})
    : borderRadius = Radii.borderSm;

  /// A placeholder shaped like an avatar.
  const Skeleton.circle({super.key, double size = 44})
    : width = size,
      height = size,
      borderRadius = const BorderRadius.all(Radius.circular(999));

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final animation = SkeletonGroup.maybeOf(context);

    // Outside a SkeletonGroup, render a static block rather than crashing -
    // a still placeholder is still a valid loading state.
    if (animation == null) {
      return _Block(
        width: width,
        height: height,
        borderRadius: borderRadius,
        color: semantic.skeletonBase,
      );
    }

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return _Block(
          width: width,
          height: height,
          borderRadius: borderRadius,
          color: Color.lerp(
            semantic.skeletonBase,
            semantic.skeletonHighlight,
            animation.value,
          )!,
        );
      },
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.color,
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
    );
  }
}

/// A placeholder list that mirrors the shape of a card list, so the layout does
/// not jump when the real content arrives.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return SkeletonGroup(
      child: Semantics(
        label: 'Loading',
        child: Column(
          children: List.generate(
            itemCount,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: Gap.md),
              child: _SkeletonCard(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.lg),
      decoration: BoxDecoration(
        borderRadius: Radii.borderLg,
        border: Border.all(color: context.semanticColors.hairline),
      ),
      child: const Row(
        children: [
          Skeleton.circle(),
          HGap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.text(width: 140),
                VGap.sm,
                Skeleton.text(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
