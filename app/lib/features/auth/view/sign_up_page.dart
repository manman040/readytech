import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/helpers/validators.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/app_card.dart';
import 'package:readytech/core/widgets/app_text_field.dart';
import 'package:readytech/data/models/user_role.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/bloc/sign_up_cubit.dart';
import 'package:readytech/features/auth/widgets/auth_scaffold.dart';

/// Account creation, for customers and technicians alike.
///
/// Only asks for what is needed to create an account. Devices, addresses,
/// skills and documents are collected later, in the flow where they matter -
/// a long registration form is the fastest way to lose someone whose laptop
/// just died, or a technician signing up between two jobs.
///
/// The role choice is a request, not a grant. The backend honours "technician"
/// by creating an unverified technician profile that cannot be offered work
/// until an administrator approves it; an administrator cannot be chosen at
/// all. See `handle_new_user()` in the migrations.
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SignUpCubit(getIt<AuthRepository>()),
      child: const _SignUpView(),
    );
  }
}

class _SignUpView extends StatefulWidget {
  const _SignUpView();

  @override
  State<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<_SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  UserRole _role = UserRole.customer;

  bool get _isTechnician => _role.isTechnician;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  void _selectRole(UserRole role) {
    if (role == _role) return;
    setState(() => _role = role);
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    unawaited(
      context.read<SignUpCubit>().submit(
        fullName: _fullName.text,
        email: _email.text,
        password: _password.text,
        phone: _phone.text,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No navigation on success, deliberately. Creating the account is a session
    // change - "awaiting verification", or signed in where confirmation is off
    // - and the router's single redirect acts on that. Navigating from here as
    // well raced it: arriving at the verification route before the session
    // change did sent the user back to sign-in with no explanation.
    return BlocBuilder<SignUpCubit, SubmissionState<String>>(
      builder: (context, state) {
        return AuthScaffold(
          title: 'Create your account',
          subtitle: 'It takes about a minute.',
          // See the note on the sign-in footer: this has to survive a large
          // text scale on a narrow screen.
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Already have an account?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              AppButton.text(
                label: 'Sign in',
                onPressed: () => context.pop(),
              ),
            ],
          ),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (state.isFailure)
                    Padding(
                      padding: const EdgeInsets.only(bottom: Gap.lg),
                      child: AuthErrorBanner(message: state.failure!.message),
                    ),
                  Text('Join as', style: context.text.titleSmall),
                  VGap.sm,
                  _RoleSelector(
                    value: _role,
                    enabled: !state.isInProgress,
                    onChanged: _selectRole,
                  ),
                  if (_isTechnician) ...[
                    VGap.sm,
                    Text(
                      'Technician accounts are reviewed by ReadyTech before '
                      'they can receive jobs. You add your skills and '
                      'documents after signing up.',
                      style: context.text.bodySmall,
                    ),
                  ],
                  VGap.xl,
                  AppTextField(
                    label: 'Full name',
                    controller: _fullName,
                    hint: 'Adam Rahman',
                    prefixIcon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: Validators.fullName,
                    enabled: !state.isInProgress,
                  ),
                  VGap.xl,
                  AppTextField(
                    label: 'Email',
                    controller: _email,
                    hint: 'you@example.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                    enabled: !state.isInProgress,
                  ),
                  VGap.xl,
                  AppTextField(
                    label: 'Phone number',
                    controller: _phone,
                    hint: '012 345 6789',
                    // A customer can add this when they book. A technician
                    // cannot be dispatched to a job nobody can call them about.
                    helperText: _isTechnician
                        ? 'Customers and ReadyTech need to reach you, so '
                              'this is required.'
                        : 'So your technician can reach you on the day. '
                              'You can add this later.',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: (value) =>
                        Validators.phone(value, isRequired: _isTechnician),
                    enabled: !state.isInProgress,
                  ),
                  VGap.xl,
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    helperText:
                        'At least 8 characters, with a letter and a number.',
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: Validators.password,
                    enabled: !state.isInProgress,
                    onSubmitted: (_) => _submit(),
                  ),
                  VGap.xxl,
                  AppButton(
                    label: 'Create account',
                    isBusy: state.isInProgress,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Customer or technician, side by side.
///
/// Two cards rather than a dropdown or a switch: both options are visible at
/// once, each explains itself in a line, and a technician does not have to
/// discover that the choice exists.
class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final UserRole value;
  final bool enabled;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight so the two cards match the taller one; a Row cannot
    // stretch its children inside a scroll view without a bounded height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _RoleOption(
              role: UserRole.customer,
              icon: Icons.devices_other_rounded,
              description: 'I need help with my devices.',
              isSelected: value.isCustomer,
              enabled: enabled,
              onTap: onChanged,
            ),
          ),
          HGap.md,
          Expanded(
            child: _RoleOption(
              role: UserRole.technician,
              icon: Icons.handyman_rounded,
              description: 'I repair devices and want jobs.',
              isSelected: value.isTechnician,
              enabled: enabled,
              onTap: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.role,
    required this.icon,
    required this.description,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final UserRole role;
  final IconData icon;
  final String description;
  final bool isSelected;
  final bool enabled;
  final ValueChanged<UserRole> onTap;

  @override
  Widget build(BuildContext context) {
    final accent = isSelected
        ? context.colors.primary
        : context.colors.onSurfaceVariant;

    return Semantics(
      selected: isSelected,
      child: AppCard(
        onTap: enabled ? () => onTap(role) : null,
        isHighlighted: isSelected,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent),
                const Spacer(),
                Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: accent,
                ),
              ],
            ),
            VGap.md,
            Text(role.label, style: context.text.titleSmall),
            VGap.xxs,
            Text(description, style: context.text.bodySmall),
          ],
        ),
      ),
    );
  }
}
