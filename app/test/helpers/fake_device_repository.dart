import 'dart:async';

import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/models/device_type.dart';
import 'package:readytech/data/repositories/device_repository.dart';

Device buildDevice({
  String id = 'device-1',
  String ownerId = 'user-1',
  DeviceType type = DeviceType.laptop,
  String nickname = 'Work laptop',
  String? brand = 'ASUS',
  String? model = 'TUF Gaming F15',
  String? serialNumber,
  DateTime? purchaseDate,
  String? notes,
}) {
  return Device(
    id: id,
    ownerId: ownerId,
    type: type,
    nickname: nickname,
    brand: brand,
    model: model,
    serialNumber: serialNumber,
    purchaseDate: purchaseDate,
    notes: notes,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// A fake that holds a real list, so adding a device and then listing shows it
/// - the behaviour the screens depend on.
class FakeDeviceRepository implements DeviceRepository {
  FakeDeviceRepository({List<Device> devices = const []})
    : _devices = [...devices];

  final List<Device> _devices;

  /// When set, [listDevices] fails with this.
  Failure? listFailure;

  /// When set, [addDevice] fails with this.
  Failure? addFailure;

  /// Hold a call open until completed, so a test can observe the in-flight
  /// frame a slow connection would produce.
  Completer<void>? listGate;
  Completer<void>? addGate;

  int listCallCount = 0;
  int addCallCount = 0;

  /// The draft most recently passed to [addDevice].
  DeviceDraft? lastDraft;

  @override
  Future<Result<List<Device>>> listDevices() async {
    listCallCount += 1;
    if (listGate != null) await listGate!.future;
    if (listFailure != null) return failed(listFailure!);
    return success(List.unmodifiable(_devices));
  }

  @override
  Future<Result<Device>> addDevice(DeviceDraft draft) async {
    addCallCount += 1;
    lastDraft = draft;
    if (addGate != null) await addGate!.future;
    if (addFailure != null) return failed(addFailure!);

    // Round-trips through the insert payload, so the device comes back
    // normalised the way the real backend would return it.
    final row = draft.toInsertJson(ownerId: 'user-1');
    final device = buildDevice(
      id: 'device-${_devices.length + 1}',
      type: draft.type,
      nickname: row['nickname'] as String,
      brand: row['brand'] as String?,
      model: row['model'] as String?,
      serialNumber: row['serial_number'] as String?,
      purchaseDate: draft.purchaseDate,
      notes: row['notes'] as String?,
    );
    _devices.insert(0, device);
    return success(device);
  }
}
