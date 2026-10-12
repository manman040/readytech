import 'package:bloc/bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/utils/result.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/repositories/device_repository.dart';

/// Drives the add-device form.
///
/// The value carried on success is the device as the backend stored it, so the
/// list can show it without a second round trip.
class AddDeviceCubit extends Cubit<SubmissionState<Device>> {
  AddDeviceCubit(this._repository) : super(const SubmissionState.idle());

  final DeviceRepository _repository;

  Future<void> submit(DeviceDraft draft) async {
    if (state.isInProgress) return;

    emit(const SubmissionState.inProgress());

    final result = await _repository.addDevice(draft);
    if (isClosed) return;

    emit(
      result.when(
        onSuccess: SubmissionState<Device>.success,
        onFailure: SubmissionState<Device>.failure,
      ),
    );
  }
}
