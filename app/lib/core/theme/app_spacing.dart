import 'package:flutter/widgets.dart';

/// A 4pt spacing scale.
///
/// Every gap, pad and inset in ReadyTech comes from this ramp. Arbitrary values
/// like `EdgeInsets.all(13)` are how a layout stops feeling deliberate.
abstract final class Gap {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 48.0;

  /// Standard horizontal page inset.
  static const page = 20.0;
}

/// Vertical and horizontal spacers, so layouts read as a list of content and
/// gaps rather than a nest of Padding widgets.
abstract final class VGap {
  static const xxs = SizedBox(height: Gap.xxs);
  static const xs = SizedBox(height: Gap.xs);
  static const sm = SizedBox(height: Gap.sm);
  static const md = SizedBox(height: Gap.md);
  static const lg = SizedBox(height: Gap.lg);
  static const xl = SizedBox(height: Gap.xl);
  static const xxl = SizedBox(height: Gap.xxl);
  static const xxxl = SizedBox(height: Gap.xxxl);
  static const huge = SizedBox(height: Gap.huge);
}

abstract final class HGap {
  static const xs = SizedBox(width: Gap.xs);
  static const sm = SizedBox(width: Gap.sm);
  static const md = SizedBox(width: Gap.md);
  static const lg = SizedBox(width: Gap.lg);
  static const xl = SizedBox(width: Gap.xl);
}

/// Corner radii. ReadyTech uses a small, consistent set - crisp rather than
/// pill-shaped, which keeps the product reading as a tool.
abstract final class Radii {
  static const sm = Radius.circular(8);
  static const md = Radius.circular(12);
  static const lg = Radius.circular(16);
  static const xl = Radius.circular(24);

  static const borderSm = BorderRadius.all(sm);
  static const borderMd = BorderRadius.all(md);
  static const borderLg = BorderRadius.all(lg);
  static const borderXl = BorderRadius.all(xl);

  /// Bottom sheets and other surfaces that rise from an edge.
  static const sheet = BorderRadius.vertical(top: Radius.circular(20));
}

/// Minimum interactive target. Below 48dp a control is hard to hit reliably,
/// which is an accessibility problem before it is a polish problem.
abstract final class Touch {
  static const minTarget = 48.0;
  static const buttonHeight = 52.0;
  static const fieldHeight = 56.0;
}

/// Motion durations. Transitions should be quick enough to feel like the app is
/// keeping up with the user.
abstract final class Motion {
  static const instant = Duration(milliseconds: 100);
  static const fast = Duration(milliseconds: 180);
  static const normal = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 400);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standard = Curves.easeOut;
}
