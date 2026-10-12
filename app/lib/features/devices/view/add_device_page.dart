import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/helpers/validators.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/app_text_field.dart';
import 'package:readytech/data/models/device.dart';
import 'package:readytech/data/models/device_type.dart';
import 'package:readytech/data/repositories/device_repository.dart';
import 'package:readytech/features/devices/bloc/add_device_cubit.dart';
import 'package:readytech/features/devices/widgets/device_type_icon.dart';

/// Registers a device.
///
/// Only the kind of device and a name are required. Everything else helps a
/// technician prepare, but a customer who does not know their model number
/// should still be able to finish the form.
class AddDevicePage extends StatelessWidget {
  const AddDevicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AddDeviceCubit(getIt<DeviceRepository>()),
      child: const _AddDeviceView(),
    );
  }
}

class _AddDeviceView extends StatefulWidget {
  const _AddDeviceView();

  @override
  State<_AddDeviceView> createState() => _AddDeviceViewState();
}

class _AddDeviceViewState extends State<_AddDeviceView> {
  final _formKey = GlobalKey<FormState>();
  final _nickname = TextEditingController();
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _serialNumber = TextEditingController();
  final _notes = TextEditingController();

  DeviceType? _type;
  DateTime? _purchaseDate;

  @override
  void dispose() {
    _nickname.dispose();
    _brand.dispose();
    _model.dispose();
    _serialNumber.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    final type = _type;
    if (!(_formKey.currentState?.validate() ?? false) || type == null) return;

    unawaited(
      context.read<AddDeviceCubit>().submit(
        DeviceDraft(
          type: type,
          nickname: _nickname.text,
          brand: _brand.text,
          model: _model.text,
          serialNumber: _serialNumber.text,
          purchaseDate: _purchaseDate,
          notes: _notes.text,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AddDeviceCubit, SubmissionState<Device>>(
      listener: (context, state) {
        if (state.isSuccess) {
          // Hands the saved device back to the list that opened this form.
          context.pop(state.value);
        } else if (state.isFailure) {
          context.showFailure(state.failure!);
        }
      },
      builder: (context, state) {
        // Stays busy after success, while the screen closes. Going back to an
        // enabled button for those few frames would let a second tap save the
        // device twice.
        final isSaving = state.isInProgress || state.isSuccess;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add a device'),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                Gap.page,
                Gap.sm,
                Gap.page,
                Gap.xxl,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _DeviceTypeField(
                          enabled: !isSaving,
                          onChanged: (type) => _type = type,
                        ),
                        VGap.xl,
                        AppTextField(
                          label: 'Name',
                          controller: _nickname,
                          hint: 'Work laptop',
                          helperText:
                              'Whatever you call it, so you can tell your '
                              'devices apart.',
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          validator: Validators.deviceNickname,
                          enabled: !isSaving,
                        ),
                        VGap.xxxl,
                        Text(
                          'Optional details',
                          style: context.text.titleMedium,
                        ),
                        VGap.xs,
                        Text(
                          'These help a technician prepare. Leave blank '
                          'anything you do not know.',
                          style: context.text.bodyMedium,
                        ),
                        VGap.xl,
                        AppTextField(
                          label: 'Brand',
                          controller: _brand,
                          hint: 'ASUS',
                          maxLength: 60,
                          textInputAction: TextInputAction.next,
                          enabled: !isSaving,
                        ),
                        VGap.xl,
                        AppTextField(
                          label: 'Model',
                          controller: _model,
                          hint: 'TUF Gaming F15',
                          maxLength: 80,
                          textInputAction: TextInputAction.next,
                          enabled: !isSaving,
                        ),
                        VGap.xl,
                        AppTextField(
                          label: 'Serial number',
                          controller: _serialNumber,
                          helperText:
                              'Usually on a sticker underneath or on the back.',
                          maxLength: 60,
                          textInputAction: TextInputAction.next,
                          enabled: !isSaving,
                        ),
                        VGap.xl,
                        _PurchaseDateField(
                          value: _purchaseDate,
                          enabled: !isSaving,
                          onChanged: (date) =>
                              setState(() => _purchaseDate = date),
                        ),
                        VGap.xl,
                        AppTextField(
                          label: 'Notes',
                          controller: _notes,
                          hint: 'Anything a technician should know',
                          maxLines: 3,
                          maxLength: 500,
                          keyboardType: TextInputType.multiline,
                          enabled: !isSaving,
                        ),
                        VGap.xxl,
                        AppButton(
                          label: 'Save device',
                          isBusy: isSaving,
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The kind-of-device picker.
///
/// Nothing is selected to begin with. A default would save one tap and quietly
/// file every printer as a laptop for anyone who skipped past it.
class _DeviceTypeField extends StatelessWidget {
  const _DeviceTypeField({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<DeviceType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return FormField<DeviceType>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (value) =>
          value == null ? 'Choose what kind of device this is' : null,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What kind of device is it?',
              style: theme.textTheme.titleSmall,
            ),
            VGap.sm,
            Wrap(
              spacing: Gap.sm,
              runSpacing: Gap.sm,
              children: [
                for (final type in DeviceType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    // The tick, not just the colour, marks the selection.
                    avatar: Icon(
                      field.value == type ? Icons.check_rounded : type.icon,
                      size: 18,
                      color: field.value == type
                          ? scheme.onPrimaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    selected: field.value == type,
                    showCheckmark: false,
                    selectedColor: scheme.primaryContainer,
                    labelStyle: theme.textTheme.labelMedium?.copyWith(
                      color: field.value == type
                          ? scheme.onPrimaryContainer
                          : null,
                    ),
                    onSelected: enabled
                        ? (_) {
                            field.didChange(type);
                            onChanged(type);
                          }
                        : null,
                  ),
              ],
            ),
            if (field.hasError) ...[
              VGap.xs,
              Text(
                field.errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A date that is picked rather than typed, laid out like [AppTextField].
class _PurchaseDateField extends StatelessWidget {
  const _PurchaseDateField({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final DateTime? value;
  final bool enabled;
  final ValueChanged<DateTime?> onChanged;

  static final _format = DateFormat('d MMM yyyy');

  Future<void> _pick(BuildContext context) async {
    // Drop focus first. A text field that still has it takes it back when the
    // picker closes and scrolls itself into view, which throws the form back
    // up to wherever the customer was last typing. Unfocusing the field itself,
    // rather than its scope, is what makes the scope forget it.
    FocusManager.instance.primaryFocus?.unfocus();

    final latest = DeviceDraft.latestPurchaseDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? latest,
      firstDate: DateTime(1990),
      lastDate: latest,
      helpText: 'Purchase date',
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Purchase date', style: theme.textTheme.titleSmall),
        VGap.sm,
        InkWell(
          onTap: enabled ? () => unawaited(_pick(context)) : null,
          borderRadius: Radii.borderMd,
          child: InputDecorator(
            isEmpty: date == null,
            decoration: InputDecoration(
              hintText: 'Select a date',
              enabled: enabled,
              prefixIcon: const Icon(Icons.event_outlined, size: 20),
              suffixIcon: date == null
                  ? null
                  : IconButton(
                      onPressed: enabled ? () => onChanged(null) : null,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      tooltip: 'Clear date',
                    ),
            ),
            child: date == null
                ? null
                : Text(_format.format(date), style: theme.textTheme.bodyLarge),
          ),
        ),
        VGap.xs,
        Text(
          'A rough date is fine.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
