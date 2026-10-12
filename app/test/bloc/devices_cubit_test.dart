import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/models/device_type.dart';
import 'package:readytech/features/devices/bloc/add_device_cubit.dart';
import 'package:readytech/features/devices/bloc/devices_cubit.dart';
import 'package:readytech/features/devices/bloc/devices_state.dart';

import '../helpers/fake_device_repository.dart';

const _draft = DeviceDraft(type: DeviceType.printer, nickname: 'Home printer');

void main() {
  group('DevicesCubit', () {
    test('starts loading, so the screen opens on a skeleton', () {
      final cubit = DevicesCubit(FakeDeviceRepository());

      expect(cubit.state, isA<DevicesLoading>());
    });

    test('loads the devices', () async {
      final device = buildDevice();
      final cubit = DevicesCubit(FakeDeviceRepository(devices: [device]));

      await cubit.load();

      expect(cubit.state, DevicesLoaded([device]));
      await cubit.close();
    });

    test('loads an empty list as loaded, not as a failure', () async {
      final cubit = DevicesCubit(FakeDeviceRepository());

      await cubit.load();

      expect(cubit.state, const DevicesLoaded([]));
      await cubit.close();
    });

    test('reports a failed load', () async {
      final repository = FakeDeviceRepository()
        ..listFailure = const NetworkFailure();
      final cubit = DevicesCubit(repository);

      await cubit.load();

      expect(cubit.state, const DevicesFailed(NetworkFailure()));
      await cubit.close();
    });

    test('shows the skeleton again while retrying after a failure', () async {
      final repository = FakeDeviceRepository(devices: [buildDevice()])
        ..listFailure = const NetworkFailure();
      final cubit = DevicesCubit(repository);
      await cubit.load();

      repository.listFailure = null;
      final states = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[isA<DevicesLoading>(), isA<DevicesLoaded>()]),
      );
      await cubit.load();

      await states;
      await cubit.close();
    });

    test('puts a newly added device at the top without reloading', () async {
      final existing = buildDevice();
      final repository = FakeDeviceRepository(devices: [existing]);
      final cubit = DevicesCubit(repository);
      await cubit.load();

      final added = buildDevice(id: 'device-2', nickname: 'Home printer');
      cubit.deviceAdded(added);

      expect(cubit.state, DevicesLoaded([added, existing]));
      expect(repository.listCallCount, 1);
      await cubit.close();
    });

    test(
      'reads the list when a device is added and none is on screen',
      () async {
        final repository = FakeDeviceRepository()
          ..listFailure = const NetworkFailure();
        final cubit = DevicesCubit(repository);
        await cubit.load();

        // The save went through even though the earlier read had failed.
        repository.listFailure = null;
        final added = (await repository.addDevice(_draft)).valueOrNull!;
        cubit.deviceAdded(added);
        await cubit.stream.firstWhere((state) => state is DevicesLoaded);

        expect(cubit.state, DevicesLoaded([added]));
        await cubit.close();
      },
    );
  });

  group('AddDeviceCubit', () {
    late FakeDeviceRepository repository;

    setUp(() => repository = FakeDeviceRepository());

    test('starts idle', () {
      expect(AddDeviceCubit(repository).state.isIdle, isTrue);
    });

    test('reports progress, then succeeds with the saved device', () async {
      final cubit = AddDeviceCubit(repository);

      final states = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          predicate<SubmissionState<Device>>((s) => s.isInProgress),
          predicate<SubmissionState<Device>>((s) => s.isSuccess),
        ]),
      );

      await cubit.submit(_draft);
      await states;

      // The list shows this value, so it has to be what the backend stored.
      expect(cubit.state.value!.nickname, 'Home printer');
      expect(cubit.state.value!.type, DeviceType.printer);
      await cubit.close();
    });

    test('carries the failure through so the form can show it', () async {
      repository.addFailure = const ValidationFailure(
        message: 'Some required information is missing or invalid.',
      );
      final cubit = AddDeviceCubit(repository);

      await cubit.submit(_draft);

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.failure!.message,
        'Some required information is missing or invalid.',
      );
      await cubit.close();
    });

    test('ignores a second tap while the first is still running', () async {
      repository.addGate = Completer<void>();
      final cubit = AddDeviceCubit(repository);

      final first = cubit.submit(_draft);
      final second = cubit.submit(_draft);
      repository.addGate!.complete();
      await Future.wait([first, second]);

      // One save, not two - a double tap must not register the device twice.
      expect(repository.addCallCount, 1);
      await cubit.close();
    });

    test('can be submitted again after a failure', () async {
      repository.addFailure = const NetworkFailure();
      final cubit = AddDeviceCubit(repository);
      await cubit.submit(_draft);
      expect(cubit.state.isFailure, isTrue);

      // The connection came back; the same form has to be saveable.
      repository.addFailure = null;
      await cubit.submit(_draft);

      expect(cubit.state.isSuccess, isTrue);
      await cubit.close();
    });
  });
}
