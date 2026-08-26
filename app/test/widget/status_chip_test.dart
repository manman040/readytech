import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/widgets/status_chip.dart';
import 'package:readytech/data/models/service_status.dart';

import '../helpers/pump_app.dart';

void main() {
  group('ServiceStatusChip', () {
    testWidgets('always pairs the colour with an icon and text', (
      tester,
    ) async {
      // Colour alone cannot carry meaning for a user with a colour vision
      // deficiency, and it does not exist at all for a screen reader.
      for (final status in ServiceStatus.values) {
        await tester.pumpApp(ServiceStatusChip(status: status));

        expect(
          find.text(status.customerLabel),
          findsOneWidget,
          reason: '${status.name} must show a label',
        );
        expect(
          find.byIcon(ServiceStatusChip.iconOf(status)),
          findsOneWidget,
          reason: '${status.name} must show an icon',
        );
      }
    });

    testWidgets('gives every status a distinct icon', (tester) async {
      final icons = ServiceStatus.values.map(ServiceStatusChip.iconOf).toSet();
      expect(
        icons.length,
        ServiceStatus.values.length,
        reason:
            'two statuses sharing an icon are indistinguishable at a glance',
      );
    });

    testWidgets('uses the technician wording when asked', (tester) async {
      await tester.pumpApp(
        const ServiceStatusChip(
          status: ServiceStatus.awaitingCustomerApproval,
          forTechnician: true,
        ),
      );

      expect(find.text('Awaiting customer approval'), findsOneWidget);
      expect(find.text('Your approval needed'), findsNothing);
    });

    testWidgets('exposes the status to a screen reader', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpApp(
        const ServiceStatusChip(status: ServiceStatus.technicianOnTheWay),
      );

      expect(find.bySemanticsLabel('Status: On the way'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders in dark mode', (tester) async {
      await tester.pumpApp(
        const ServiceStatusChip(status: ServiceStatus.paid),
        brightness: Brightness.dark,
      );

      expect(find.text('Paid'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('maps live states to the reserved live tone', () {
      // The teal is reserved for realtime activity; if it starts appearing on
      // static states it stops meaning anything.
      expect(
        ServiceStatusChip.toneOf(ServiceStatus.technicianOnTheWay),
        StatusTone.live,
      );
      expect(
        ServiceStatusChip.toneOf(ServiceStatus.repairing),
        StatusTone.live,
      );
      expect(
        ServiceStatusChip.toneOf(ServiceStatus.cancelled),
        StatusTone.neutral,
      );
      expect(
        ServiceStatusChip.toneOf(ServiceStatus.disputed),
        StatusTone.danger,
      );
      expect(
        ServiceStatusChip.toneOf(ServiceStatus.awaitingCustomerApproval),
        StatusTone.warning,
      );
    });
  });
}
