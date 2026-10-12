import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/skeleton.dart';
import 'package:readytech/core/widgets/state_views.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/repositories/device_repository.dart';
import 'package:readytech/features/devices/bloc/devices_cubit.dart';
import 'package:readytech/features/devices/bloc/devices_state.dart';
import 'package:readytech/features/devices/widgets/device_card.dart';
import 'package:readytech/routing/routes.dart';

/// The customer's registered devices.
class DevicesPage extends StatelessWidget {
  const DevicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = DevicesCubit(getIt<DeviceRepository>());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _DevicesView(),
    );
  }
}

class _DevicesView extends StatelessWidget {
  const _DevicesView();

  static const _listPadding = EdgeInsets.fromLTRB(
    Gap.page,
    Gap.sm,
    Gap.page,
    Gap.lg,
  );

  Future<void> _addDevice(BuildContext context) async {
    final device = await context.pushNamed<Device>(
      AppRoute.customerAddDevice.name,
    );
    // Null when the form was closed without saving.
    if (device == null || !context.mounted) return;

    context.read<DevicesCubit>().deviceAdded(device);
    context.showSnack(
      '${device.nickname} added',
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Devices'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: BlocBuilder<DevicesCubit, DevicesState>(
          builder: (context, state) => switch (state) {
            DevicesLoading() => const SingleChildScrollView(
              padding: _listPadding,
              child: SkeletonList(),
            ),
            DevicesFailed(:final failure) => AppErrorState(
              failure: failure,
              title: 'We could not load your devices',
              onRetry: () => unawaited(context.read<DevicesCubit>().load()),
            ),
            DevicesLoaded(:final devices) when devices.isEmpty => AppEmptyState(
              icon: Icons.devices_other_outlined,
              title: 'No devices yet',
              message:
                  'Add your laptop, printer or router so a technician knows '
                  'what they are coming to fix.',
              actionLabel: 'Add a device',
              onAction: () => unawaited(_addDevice(context)),
            ),
            DevicesLoaded(:final devices) => Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: _listPadding,
                    itemCount: devices.length,
                    separatorBuilder: (_, _) => VGap.md,
                    itemBuilder: (_, index) =>
                        DeviceCard(device: devices[index]),
                  ),
                ),
                // Pinned, so adding another device never means scrolling to
                // the end of a long list first.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Gap.page,
                    Gap.sm,
                    Gap.page,
                    Gap.lg,
                  ),
                  child: AppButton(
                    label: 'Add a device',
                    icon: Icons.add_rounded,
                    onPressed: () => unawaited(_addDevice(context)),
                  ),
                ),
              ],
            ),
          },
        ),
      ),
    );
  }
}
