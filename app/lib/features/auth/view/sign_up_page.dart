import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/helpers/validators.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/app_text_field.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/bloc/sign_up_cubit.dart';
import 'package:readytech/features/auth/widgets/auth_scaffold.dart';
import 'package:readytech/routing/routes.dart';

/// Account creation.
///
/// Only asks for what is needed to create an account. Devices, addresses and
/// everything else are collected later, in the flow where they matter - a long
/// registration form is the fastest way to lose someone whose laptop just died.
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

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SignUpCubit, SubmissionState<String>>(
      // The account now exists but is unverified. The session change moves the
      // router to the verification screen on its own; this only reports what
      // happened in case the user is still looking at this screen.
      listener: (context, state) {
        if (state.isSuccess) {
          context.goNamed(AppRoute.verifyEmail.name);
        }
      },
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
                    helperText:
                        'So your technician can reach you on the day. '
                        'You can add this later.',
                    prefixIcon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    validator: Validators.phone,
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
