import 'package:flutter_test/flutter_test.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/models/device_type.dart';

Map<String, dynamic> _row({
  String? deviceType = 'laptop',
  String? purchaseDate = '2024-03-15',
  String? archivedAt,
}) => {
  'id': 'device-1',
  'owner_id': 'user-1',
  'device_type': deviceType,
  'nickname': 'Work laptop',
  'brand': 'ASUS',
  'model': 'TUF Gaming F15',
  'serial_number': 'S4N2029A11',
  'purchase_date': purchaseDate,
  'notes': 'Screen flickered once before.',
  'archived_at': archivedAt,
  'created_at': '2026-08-26T03:00:00+00:00',
  'updated_at': '2026-08-26T03:00:00+00:00',
};

void main() {
  group('Device.fromJson', () {
    test('reads a full row', () {
      final device = Device.fromJson(_row());

      expect(device.id, 'device-1');
      expect(device.ownerId, 'user-1');
      expect(device.type, DeviceType.laptop);
      expect(device.nickname, 'Work laptop');
      expect(device.brand, 'ASUS');
      expect(device.model, 'TUF Gaming F15');
      expect(device.serialNumber, 'S4N2029A11');
      expect(device.notes, 'Screen flickered once before.');
      expect(device.isArchived, isFalse);
    });

    test('keeps the purchase date on the day that was picked', () {
      // A calendar date must not be shifted by a time zone conversion - a
      // receipt dated the 15th cannot turn into the 14th.
      final purchaseDate = Device.fromJson(_row()).purchaseDate!;

      expect(
        (purchaseDate.year, purchaseDate.month, purchaseDate.day),
        (2024, 3, 15),
      );
    });

    test('accepts a row with only the required columns filled in', () {
      final device = Device.fromJson({
        ..._row(purchaseDate: null),
        'brand': null,
        'model': null,
        'serial_number': null,
        'notes': null,
      });

      expect(device.brand, isNull);
      expect(device.purchaseDate, isNull);
      expect(device.makeAndModel, isNull);
    });

    test('recognises an archived device', () {
      final device = Device.fromJson(
        _row(archivedAt: '2026-09-01T00:00:00+00:00'),
      );

      expect(device.isArchived, isTrue);
    });
  });

  group('Device.makeAndModel', () {
    Device withMake({String? brand, String? model}) => Device.fromJson({
      ..._row(),
      'brand': brand,
      'model': model,
    });

    test('joins brand and model', () {
      expect(
        withMake(brand: 'ASUS', model: 'TUF Gaming F15').makeAndModel,
        'ASUS TUF Gaming F15',
      );
    });

    test('uses whichever half is known', () {
      expect(withMake(brand: 'Epson').makeAndModel, 'Epson');
      expect(withMake(model: 'L3210').makeAndModel, 'L3210');
      expect(withMake(brand: '  ', model: 'L3210').makeAndModel, 'L3210');
    });
  });

  group('DeviceDraft.toInsertJson', () {
    test('trims text and stores a blank optional field as null', () {
      // "Never filled in" must have one representation in the table, not an
      // empty string in some rows and null in others.
      final row = const DeviceDraft(
        type: DeviceType.networkDevice,
        nickname: '  Office router ',
        brand: ' TP-Link ',
        model: '',
        serialNumber: '   ',
      ).toInsertJson(ownerId: 'user-1');

      expect(row['owner_id'], 'user-1');
      expect(row['device_type'], 'network_device');
      expect(row['nickname'], 'Office router');
      expect(row['brand'], 'TP-Link');
      expect(row['model'], isNull);
      expect(row['serial_number'], isNull);
      expect(row['purchase_date'], isNull);
      expect(row['notes'], isNull);
    });

    test('sends the purchase date as a plain calendar date', () {
      final row = DeviceDraft(
        type: DeviceType.laptop,
        nickname: 'Work laptop',
        purchaseDate: DateTime(2024, 3, 5),
      ).toInsertJson(ownerId: 'user-1');

      expect(row['purchase_date'], '2024-03-05');
    });

    test('never writes columns the backend owns', () {
      final row = const DeviceDraft(
        type: DeviceType.laptop,
        nickname: 'Work laptop',
      ).toInsertJson(ownerId: 'user-1');

      expect(row.keys, isNot(contains('id')));
      expect(row.keys, isNot(contains('archived_at')));
      expect(row.keys, isNot(contains('created_at')));
      expect(row.keys, isNot(contains('updated_at')));
    });
  });

  group('DeviceDraft.latestPurchaseDate', () {
    test('is never later than today, here or on the database clock', () {
      // The database checks the date against its own UTC calendar. A day that
      // has started here but not there yet would be refused, so the picker
      // must not offer it. Checked across a whole day so the hours where the
      // two calendars disagree are covered whatever zone the tests run in.
      for (var hour = 0; hour < 24; hour++) {
        final now = DateTime(2026, 10, 4, hour, 30);
        final utc = now.toUtc();
        final latest = DeviceDraft.latestPurchaseDate(now);

        expect(
          latest.isAfter(DateTime(now.year, now.month, now.day)),
          isFalse,
          reason: 'offered a future local date at $now',
        );
        expect(
          latest.isAfter(DateTime(utc.year, utc.month, utc.day)),
          isFalse,
          reason: 'offered a date the database would refuse at $now',
        );
      }
    });

    test('carries no time of day', () {
      final latest = DeviceDraft.latestPurchaseDate(
        DateTime(2026, 10, 4, 13, 45),
      );

      expect((latest.hour, latest.minute, latest.second), (0, 0, 0));
    });
  });

  group('DeviceType', () {
    test('falls back to "other" for a value this build does not know', () {
      // A type added by a later migration must still render in a list.
      expect(DeviceType.fromWire('smart_fridge'), DeviceType.other);
      expect(DeviceType.fromWire(null), DeviceType.other);
      expect(DeviceType.fromWire(''), DeviceType.other);
    });

    test('round-trips every known type', () {
      for (final type in DeviceType.values) {
        expect(DeviceType.fromWire(type.wireName), type);
      }
    });

    test('matches the device_type enum in Postgres', () {
      expect(DeviceType.values.map((type) => type.wireName), [
        'laptop',
        'desktop',
        'printer',
        'network_device',
        'mobile',
        'tablet',
        'server',
        'peripheral',
        'other',
      ]);
    });

    test('gives every type its own label', () {
      final labels = DeviceType.values.map((type) => type.label).toSet();
      expect(labels.length, DeviceType.values.length);
    });
  });
}
