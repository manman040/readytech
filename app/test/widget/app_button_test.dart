import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/widgets/app_button.dart';

import '../helpers/pump_app.dart';

void main() {
  group('AppButton', () {
    testWidgets('renders its label and fires the callback', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppButton(label: 'Get Help', onPressed: () => taps += 1),
      );

      expect(find.text('Get Help'), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      expect(taps, 1);
    });

    testWidgets('suppresses the callback while busy', (tester) async {
      var taps = 0;
      await tester.pumpApp(
        AppButton(label: 'Sign in', isBusy: true, onPressed: () => taps += 1),
      );

      await tester.tap(find.byType(AppButton));
      await tester.pump();

      // A second submit here is a duplicate service request.
      expect(taps, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('keeps its size when it becomes busy', (tester) async {
      await tester.pumpApp(
        const AppButton(label: 'Approve & Continue', onPressed: _noop),
      );
      final idleSize = tester.getSize(find.byType(AppButton));

      await tester.pumpApp(
        const AppButton(
          label: 'Approve & Continue',
          isBusy: true,
          onPressed: _noop,
        ),
      );
      final busySize = tester.getSize(find.byType(AppButton));

      // A button that shrinks into a spinner moves everything below it.
      expect(busySize, idleSize);
    });

    testWidgets('is disabled when no callback is supplied', (tester) async {
      await tester.pumpApp(const AppButton(label: 'Get Help', onPressed: null));

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('renders an icon alongside the label', (tester) async {
      await tester.pumpApp(
        const AppButton(
          label: 'Get Help',
          icon: Icons.add_rounded,
          onPressed: _noop,
        ),
      );

      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.text('Get Help'), findsOneWidget);
    });

    testWidgets('announces the busy state to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpApp(
        const AppButton(label: 'Sign in', isBusy: true, onPressed: _noop),
      );

      // Falling silent while a request is in flight leaves a screen reader
      // user with no idea anything happened.
      expect(find.bySemanticsLabel('Sign in, in progress'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('each variant renders the right underlying button', (
      tester,
    ) async {
      await tester.pumpApp(
        const Column(
          children: [
            AppButton(label: 'Primary', onPressed: _noop),
            AppButton.secondary(label: 'Secondary', onPressed: _noop),
            AppButton.text(label: 'Text', onPressed: _noop),
          ],
        ),
      );

      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });

    testWidgets('meets the minimum touch target height', (tester) async {
      await tester.pumpApp(
        const AppButton(label: 'Get Help', onPressed: _noop),
      );

      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}

void _noop() {}
