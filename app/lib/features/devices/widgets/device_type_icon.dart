import 'package:flutter/material.dart';
import 'package:readytech/data/models/device_type.dart';

/// The icon for each kind of device.
///
/// Kept here rather than on the enum so [DeviceType] stays free of Flutter
/// imports - the same split as `ServiceStatus` and its chip.
extension DeviceTypeIcon on DeviceType {
  IconData get icon => switch (this) {
    DeviceType.laptop => Icons.laptop_outlined,
    DeviceType.desktop => Icons.desktop_windows_outlined,
    DeviceType.printer => Icons.print_outlined,
    DeviceType.networkDevice => Icons.router_outlined,
    DeviceType.mobile => Icons.smartphone_outlined,
    DeviceType.tablet => Icons.tablet_outlined,
    DeviceType.server => Icons.dns_outlined,
    DeviceType.peripheral => Icons.keyboard_outlined,
    DeviceType.other => Icons.devices_other_outlined,
  };
}
