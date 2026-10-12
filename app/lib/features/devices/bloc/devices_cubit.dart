import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/repositories/device_repository.dart';
import 'package:readytech/features/devices/bloc/devices_state.dart';

/// Drives the My Devices list.
class DevicesCubit extends Cubit<DevicesState> {
  DevicesCubit(this._repository) : super(const DevicesLoading());

  final DeviceRepository _repository;

  /// Reads the list. Used for the first load and for "Try again".
  Future<void> load() async {
    emit(const DevicesLoading());

    final result = await _repository.listDevices();
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: DevicesLoaded.new,
        onFailure: DevicesFailed.new,
      ),
    );
  }

  /// Shows a device that was just saved, without reading the list again.
  void deviceAdded(Device device) {
    final current = state;
    if (current is! DevicesLoaded) {
      // There is no list on screen to add it to. Read one; it will include
      // the new device.
      unawaited(load());
      return;
    }

    // Newest first, the same order the backend returns.
    emit(DevicesLoaded([device, ...current.devices]));
  }
}
