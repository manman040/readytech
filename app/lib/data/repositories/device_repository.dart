import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/core/services/app_logger.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/datasources/device_remote_datasource.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/repositories/base_repository.dart';

/// The signed-in customer's devices.
///
/// Exposed as an interface so the screens can be tested against a fake and so
/// the Supabase SDK stays behind the data layer.
abstract interface class DeviceRepository {
  /// Newest first. Archived devices are left out.
  Future<Result<List<Device>>> listDevices();

  /// Saves [draft] and returns the device as the backend stored it.
  Future<Result<Device>> addDevice(DeviceDraft draft);
}

class SupabaseDeviceRepository
    with GuardedRepository
    implements DeviceRepository {
  SupabaseDeviceRepository({
    required DeviceRemoteDataSource dataSource,
    required this.logger,
  }) : _dataSource = dataSource;

  final DeviceRemoteDataSource _dataSource;

  @override
  final AppLogger logger;

  @override
  Future<Result<List<Device>>> listDevices() {
    return guard(
      'devices.list',
      () async => _dataSource.fetchDevices(_requireUserId()),
    );
  }

  @override
  Future<Result<Device>> addDevice(DeviceDraft draft) {
    return guard(
      'devices.add',
      () async => _dataSource.insertDevice(
        // The owner is always the caller. The insert policy would refuse any
        // other value, so there is nothing to gain from accepting one here.
        draft.toInsertJson(ownerId: _requireUserId()),
      ),
    );
  }

  String _requireUserId() {
    final userId = _dataSource.currentUserId;
    if (userId == null) throw const AuthFailure.sessionExpired();
    return userId;
  }
}
