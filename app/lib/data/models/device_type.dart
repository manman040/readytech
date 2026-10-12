/// What kind of equipment a device is.
///
/// Mirrors the `device_type` enum in Postgres. The labels are written for a
/// customer rather than a technician - "Router or WiFi", not "network device" -
/// because the person choosing one is the person whose laptop just died.
enum DeviceType {
  laptop('laptop'),
  desktop('desktop'),
  printer('printer'),
  networkDevice('network_device'),
  mobile('mobile'),
  tablet('tablet'),
  server('server'),
  peripheral('peripheral'),
  other('other')
  ;

  const DeviceType(this.wireName);

  final String wireName;

  /// A value this build does not recognise - a type added by a later
  /// migration - still has to render, so it degrades to [other] rather than
  /// throwing in the middle of a list.
  static const DeviceType fallback = DeviceType.other;

  static DeviceType fromWire(String? value) {
    for (final type in DeviceType.values) {
      if (type.wireName == value) return type;
    }
    return fallback;
  }

  String get label => switch (this) {
    laptop => 'Laptop',
    desktop => 'Desktop PC',
    printer => 'Printer',
    networkDevice => 'Router or WiFi',
    mobile => 'Phone',
    tablet => 'Tablet',
    server => 'Server',
    peripheral => 'Accessory',
    other => 'Other',
  };
}
