import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/theme/app_theme.dart';

extension PumpApp on WidgetTester {
  /// Wraps [widget] in the real ReadyTech theme.
  ///
  /// Testing against the production theme rather than a bare MaterialApp means
  /// a widget that depends on the semantic colour extension - which most of the
  /// component kit does - fails here if the extension is ever dropped, rather
  /// than at runtime.
  Future<void> pumpApp(
    Widget widget, {
    Brightness brightness = Brightness.light,
    Size surfaceSize = const Size(400, 800),
  }) async {
    await binding.setSurfaceSize(surfaceSize);
    addTearDown(() => binding.setSurfaceSize(null));

    await pumpWidget(
      MaterialApp(
        theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
        home: Scaffold(body: widget),
      ),
    );
  }
}
