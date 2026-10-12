import 'package:readytech/core/constants/db.dart';
import 'package:readytech/data/models/device.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin transport layer over the `devices` table.
class DeviceRemoteDataSource {
  DeviceRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, owner_id, device_type, nickname, brand, model, serial_number, '
      'purchase_date, notes, archived_at, created_at, updated_at';

  String? get currentUserId => _client.auth.currentUser?.id;

  /// The owner's devices, newest first, leaving out archived ones.
  ///
  /// Filters on `owner_id` even though Row Level Security already scopes the
  /// table. The policies also let an administrator read every device and a
  /// technician read the one on their job, and "My Devices" means the caller's
  /// own.
  Future<List<Device>> fetchDevices(String ownerId) async {
    final rows = await _client
        .from(DbTable.devices)
        .select(_columns)
        .eq('owner_id', ownerId)
        .isFilter('archived_at', null)
        .order('created_at', ascending: false);

    return rows.map(Device.fromJson).toList();
  }

  Future<Device> insertDevice(Map<String, dynamic> values) async {
    final row = await _client
        .from(DbTable.devices)
        .insert(values)
        .select(_columns)
        .single();

    return Device.fromJson(row);
  }
}
