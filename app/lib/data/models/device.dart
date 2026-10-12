import 'package:equatable/equatable.dart';
import 'package:readytech/data/models/device_type.dart';

/// A piece of equipment a customer owns.
///
/// Registering one is optional - a request can be placed without it - but a
/// device is what a service history hangs off, and it saves describing the same
/// laptop again on the next visit.
class Device extends Equatable {
  const Device({
    required this.id,
    required this.ownerId,
    required this.type,
    required this.nickname,
    required this.createdAt,
    required this.updatedAt,
    this.brand,
    this.model,
    this.serialNumber,
    this.purchaseDate,
    this.notes,
    this.archivedAt,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    final purchaseDate = json['purchase_date'] as String?;
    final archivedAt = json['archived_at'] as String?;

    return Device(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      type: DeviceType.fromWire(json['device_type'] as String?),
      nickname: json['nickname'] as String? ?? '',
      brand: json['brand'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serial_number'] as String?,
      // A calendar date, not an instant. It parses as local midnight and is
      // never shifted, so it reads back as the day the customer picked.
      purchaseDate: purchaseDate == null ? null : DateTime.parse(purchaseDate),
      notes: json['notes'] as String?,
      archivedAt: archivedAt == null
          ? null
          : DateTime.parse(archivedAt).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }

  final String id;
  final String ownerId;
  final DeviceType type;

  /// What the customer calls it: "Work laptop", "Office printer".
  final String nickname;

  final String? brand;
  final String? model;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final String? notes;

  /// Devices are archived, never deleted, because completed services reference
  /// them.
  final DateTime? archivedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  /// Brand and model on one line, e.g. "ASUS TUF Gaming F15". `null` when
  /// neither was recorded.
  String? get makeAndModel {
    final parts = [
      brand,
      model,
    ].map((part) => part?.trim() ?? '').where((part) => part.isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }

  @override
  List<Object?> get props => [
    id,
    ownerId,
    type,
    nickname,
    brand,
    model,
    serialNumber,
    purchaseDate,
    notes,
    archivedAt,
    createdAt,
    updatedAt,
  ];
}

/// A device that has not been saved yet - what the add-device form produces.
class DeviceDraft extends Equatable {
  const DeviceDraft({
    required this.type,
    required this.nickname,
    this.brand,
    this.model,
    this.serialNumber,
    this.purchaseDate,
    this.notes,
  });

  final DeviceType type;
  final String nickname;
  final String? brand;
  final String? model;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final String? notes;

  /// The most recent purchase date the backend will accept.
  ///
  /// `devices_purchase_date_not_future` compares against the database's own
  /// date, and the database keeps UTC. Malaysia is eight hours ahead, so until
  /// 8am "today" here is still "tomorrow" there and would be refused. Stopping
  /// at the earlier of the two dates means the picker never offers a day that
  /// cannot be saved.
  static DateTime latestPurchaseDate([DateTime? now]) {
    final local = (now ?? DateTime.now()).toLocal();
    final utc = local.toUtc();
    final localDay = DateTime(local.year, local.month, local.day);
    final utcDay = DateTime(utc.year, utc.month, utc.day);
    return utcDay.isBefore(localDay) ? utcDay : localDay;
  }

  /// The row to insert.
  ///
  /// Text is trimmed and a blank optional field becomes `null`, so "never
  /// filled in" has one representation in the table instead of two.
  Map<String, dynamic> toInsertJson({required String ownerId}) => {
    'owner_id': ownerId,
    'device_type': type.wireName,
    'nickname': nickname.trim(),
    'brand': _nullIfBlank(brand),
    'model': _nullIfBlank(model),
    'serial_number': _nullIfBlank(serialNumber),
    'purchase_date': _dateOnly(purchaseDate),
    'notes': _nullIfBlank(notes),
  };

  static String? _nullIfBlank(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Postgres `date` wants `yyyy-MM-dd`. Sending a full timestamp would let a
  /// time zone conversion move the day.
  static String? _dateOnly(DateTime? value) {
    if (value == null) return null;
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  @override
  List<Object?> get props => [
    type,
    nickname,
    brand,
    model,
    serialNumber,
    purchaseDate,
    notes,
  ];
}
