import 'package:flutter/material.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/core/widgets/app_card.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/features/devices/widgets/device_type_icon.dart';

/// One device in the My Devices list.
///
/// Leads with the name the customer gave it. "Work laptop" is how they think
/// of it; the brand and model are detail for the technician.
class DeviceCard extends StatelessWidget {
  const DeviceCard({required this.device, super.key});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final details = [device.type.label, ?device.makeAndModel].join(' · ');

    return AppCard(
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: semantic.neutralContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              device.type.icon,
              size: 22,
              color: semantic.onNeutralContainer,
            ),
          ),
          HGap.md,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.nickname,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                VGap.xxs,
                Text(
                  details,
                  style: context.text.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
