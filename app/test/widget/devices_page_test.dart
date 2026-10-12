import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/app_text_field.dart';
import 'package:readytech/core/widgets/skeleton.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/models/device_type.dart';
import 'package:readytech/data/repositories/device_repository.dart';
import 'package:readytech/features/devices/view/add_device_page.dart';
import 'package:readytech/features/devices/view/devices_page.dart';
import 'package:readytech/features/devices/widgets/device_card.dart';
import 'package:readytech/features/devices/widgets/device_type_icon.dart';
import 'package:readytech/routing/routes.dart';

import '../helpers/fake_device_repository.dart';

void main() {
  late FakeDeviceRepository repository;

  void useRepository(FakeDeviceRepository fake) {
    repository = fake;
    getIt.registerSingleton<DeviceRepository>(fake);
  }

  tearDown(getIt.reset);

  /// The list opens the form by route name and the form pops back with the
  /// saved device, so both need a real router around them.
  ///
  /// The surface is taller than a phone so the whole form is on screen. A
  /// focused field scrolls itself back into view, which would otherwise fight
  /// any attempt to scroll down to the save button.
  Future<void> pumpDevices(WidgetTester tester, {bool settle = true}) async {
    await tester.binding.setSurfaceSize(const Size(400, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: AppRoute.customerDevices.path,
              name: AppRoute.customerDevices.name,
              builder: (_, _) => const DevicesPage(),
            ),
            GoRoute(
              path: AppRoute.customerAddDevice.path,
              name: AppRoute.customerAddDevice.name,
              builder: (_, _) => const AddDevicePage(),
            ),
          ],
          initialLocation: AppRoute.customerDevices.path,
        ),
      ),
    );
    // The skeleton animates forever, so a loading screen never settles.
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('Add a device'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.descendant(
    of: find.widgetWithText(AppTextField, label),
    matching: find.byType(TextFormField),
  );

  /// The label is replaced by a spinner while saving, so the button has to be
  /// found by identity rather than by its text.
  Finder saveButton() => find.byWidgetPredicate(
    (widget) => widget is AppButton && widget.label == 'Save device',
  );

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(saveButton());
    await tester.pump();
  }

  group('DevicesPage', () {
    testWidgets('shows a skeleton while the list is loading', (tester) async {
      final gate = Completer<void>();
      useRepository(FakeDeviceRepository()..listGate = gate);

      await pumpDevices(tester, settle: false);

      expect(find.byType(SkeletonList), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
    });

    testWidgets('lists each device with its name, type and model', (
      tester,
    ) async {
      useRepository(
        FakeDeviceRepository(
          devices: [
            buildDevice(),
            buildDevice(
              id: 'device-2',
              type: DeviceType.printer,
              nickname: 'Home printer',
              brand: 'Epson',
              model: 'L3210',
            ),
          ],
        ),
      );

      await pumpDevices(tester);

      expect(find.byType(DeviceCard), findsNWidgets(2));
      expect(find.text('Work laptop'), findsOneWidget);
      expect(find.text('Laptop · ASUS TUF Gaming F15'), findsOneWidget);
      expect(find.text('Home printer'), findsOneWidget);
      expect(find.text('Printer · Epson L3210'), findsOneWidget);
    });

    testWidgets('shows only the type when brand and model are unknown', (
      tester,
    ) async {
      useRepository(
        FakeDeviceRepository(
          devices: [
            buildDevice(
              type: DeviceType.networkDevice,
              nickname: 'Office router',
              brand: null,
              model: null,
            ),
          ],
        ),
      );

      await pumpDevices(tester);

      expect(find.text('Router or WiFi'), findsOneWidget);
    });

    testWidgets('offers a next step when there are no devices', (tester) async {
      useRepository(FakeDeviceRepository());

      await pumpDevices(tester);

      // An empty list is not a dead end.
      expect(find.text('No devices yet'), findsOneWidget);
      expect(find.text('Add a device'), findsOneWidget);
    });

    testWidgets('shows the failure without leaking driver text', (
      tester,
    ) async {
      useRepository(
        FakeDeviceRepository()
          ..listFailure = const ServerFailure(
            debugDetail: 'PostgrestException(code: 42P01, relation "devices")',
          ),
      );

      await pumpDevices(tester);

      expect(find.text('We could not load your devices'), findsOneWidget);
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('42P01'), findsNothing);
    });

    testWidgets('retries a failed load', (tester) async {
      useRepository(
        FakeDeviceRepository(devices: [buildDevice()])
          ..listFailure = const NetworkFailure(),
      );
      await pumpDevices(tester);
      expect(find.text('You are offline'), findsOneWidget);

      repository.listFailure = null;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Work laptop'), findsOneWidget);
      expect(repository.listCallCount, 2);
    });

    testWidgets('gives every device type a distinct icon', (tester) async {
      final icons = DeviceType.values.map((type) => type.icon).toSet();

      expect(
        icons.length,
        DeviceType.values.length,
        reason: 'two types sharing an icon look the same in the list',
      );
    });
  });

  group('adding a device', () {
    testWidgets('saves the form and shows the new device in the list', (
      tester,
    ) async {
      useRepository(FakeDeviceRepository(devices: [buildDevice()]));
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Printer'));
      await tester.enterText(field('Name'), '  Home printer ');
      await tester.enterText(field('Brand'), 'Epson');
      await tester.enterText(field('Model'), 'L3210');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.addCallCount, 1);
      expect(repository.lastDraft!.type, DeviceType.printer);

      // Back on the list, newest first, without a second read.
      expect(find.text('Home printer'), findsOneWidget);
      expect(find.text('Printer · Epson L3210'), findsOneWidget);
      expect(find.text('Home printer added'), findsOneWidget);
      expect(repository.listCallCount, 1);
      final cards = tester.widgetList<DeviceCard>(find.byType(DeviceCard));
      expect(cards.first.device.nickname, 'Home printer');
    });

    testWidgets('saves with only the required fields', (tester) async {
      useRepository(FakeDeviceRepository());
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Laptop'));
      await tester.enterText(field('Name'), 'Work laptop');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.addCallCount, 1);
      expect(find.text('Work laptop'), findsOneWidget);
      expect(find.text('No devices yet'), findsNothing);
    });

    testWidgets('records a picked purchase date', (tester) async {
      useRepository(FakeDeviceRepository());
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Laptop'));
      await tester.enterText(field('Name'), 'Work laptop');
      await tester.tap(find.text('Select a date'));
      await tester.pumpAndSettle();
      // The picker opens on the latest date the backend accepts.
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      final latest = DeviceDraft.latestPurchaseDate();
      expect(
        find.text(DateFormat('d MMM yyyy').format(latest)),
        findsOneWidget,
      );

      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(repository.lastDraft!.purchaseDate, latest);
    });

    testWidgets('clears a purchase date picked by mistake', (tester) async {
      useRepository(FakeDeviceRepository());
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Select a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Clear date'));
      await tester.pumpAndSettle();

      expect(find.text('Select a date'), findsOneWidget);
      expect(find.byTooltip('Clear date'), findsNothing);
    });

    testWidgets('does not hand focus back to a text field after the picker', (
      tester,
    ) async {
      useRepository(FakeDeviceRepository());
      await pumpDevices(tester);
      await openForm(tester);

      await tester.enterText(field('Name'), 'Work laptop');
      await tester.tap(find.text('Select a date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // A field that regained focus would scroll itself back into view and
      // drag the form away from the date the customer was just setting.
      final name = tester.widget<EditableText>(
        find.descendant(of: field('Name'), matching: find.byType(EditableText)),
      );
      expect(name.focusNode.hasFocus, isFalse);
    });

    testWidgets('refuses to save without a device type', (tester) async {
      useRepository(FakeDeviceRepository());
      await pumpDevices(tester);
      await openForm(tester);

      await tester.enterText(field('Name'), 'Work laptop');
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Choose what kind of device this is'), findsOneWidget);
      expect(repository.addCallCount, 0);
    });

    testWidgets('refuses to save without a name', (tester) async {
      useRepository(FakeDeviceRepository());
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Laptop'));
      await tapSave(tester);
      await tester.pumpAndSettle();

      expect(find.text('Give this device a name'), findsOneWidget);
      expect(repository.addCallCount, 0);
    });

    testWidgets('stays on the form and explains a failed save', (tester) async {
      useRepository(
        FakeDeviceRepository()
          ..addFailure = const ServerFailure(
            debugDetail: 'PostgrestException(code: 23514, devices_nickname)',
          ),
      );
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Laptop'));
      await tester.enterText(field('Name'), 'Work laptop');
      await tapSave(tester);
      await tester.pumpAndSettle();

      // What was typed is still there to try again with.
      expect(find.text('Save device'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(field('Name')).controller!.text,
        'Work laptop',
      );
      expect(
        find.text('Something went wrong on our side. Please try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('PostgrestException'), findsNothing);
    });

    testWidgets('does not save twice on a double tap', (tester) async {
      final gate = Completer<void>();
      useRepository(FakeDeviceRepository()..addGate = gate);
      await pumpDevices(tester);
      await openForm(tester);

      await tester.tap(find.text('Laptop'));
      await tester.enterText(field('Name'), 'Work laptop');
      await tapSave(tester);

      expect(tester.widget<AppButton>(saveButton()).isBusy, isTrue);
      // The button is now a spinner; tapping it again must do nothing.
      await tester.tap(saveButton(), warnIfMissed: false);
      await tester.pump();

      expect(repository.addCallCount, 1);

      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('leaves the list alone when the form is closed unsaved', (
      tester,
    ) async {
      useRepository(FakeDeviceRepository(devices: [buildDevice()]));
      await pumpDevices(tester);
      await openForm(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DeviceCard), findsOneWidget);
      expect(repository.addCallCount, 0);
    });
  });
}
