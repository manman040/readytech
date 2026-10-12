import 'package:equatable/equatable.dart';
import 'package:readytech/core/errors/failure.dart';
import 'package:readytech/data/models/device.dart';

/// What the My Devices list is showing.
sealed class DevicesState extends Equatable {
  const DevicesState();

  @override
  List<Object?> get props => [];
}

/// The list is being read. The screen shows a skeleton.
class DevicesLoading extends DevicesState {
  const DevicesLoading();
}

/// The list was read. [devices] may be empty, which is its own screen state.
class DevicesLoaded extends DevicesState {
  const DevicesLoaded(this.devices);

  /// Newest first.
  final List<Device> devices;

  @override
  List<Object?> get props => [devices];
}

/// The list could not be read.
class DevicesFailed extends DevicesState {
  const DevicesFailed(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}
