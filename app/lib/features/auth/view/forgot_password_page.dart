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
import 'package:readytech/core/widgets/state_views.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/bloc/password_reset_cubit.dart';
import 'package:readytech/features/auth/widgets/auth_scaffold.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PasswordResetCubit(getIt<AuthRepository>()),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatefulWidget {
  const _ForgotPasswordView();

  @override
  State<_ForgotPasswordView> createState() => _ForgotPasswordViewState();
}

class _ForgotPasswordViewState extends State<_ForgotPasswordView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    unawaited(context.read<PasswordResetCubit>().sendResetLink(_email.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PasswordResetCubit, SubmissionState<void>>(
      builder: (context, state) {
        if (state.isSuccess) {
          return Scaffold(
            appBar: AppBar(backgroundColor: Colors.transparent),
            body: AppEmptyState(
              icon: Icons.mark_email_read_outlined,
              title: 'Check your inbox',
              message:
                  'If an account exists for ${_email.text.trim()}, a reset link '
                  'is on its way. The link expires in one hour.',
              actionLabel: 'Back to sign in',
              onAction: () => context.pop(),
            ),
          );
        }

        return AuthScaffold(
          title: 'Reset your password',
          subtitle:
              "Enter the email you signed up with and we'll send you a link.",
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
                    label: 'Email',
                    controller: _email,
                    hint: 'you@example.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                    enabled: !state.isInProgress,
                    autofocus: true,
                    onSubmitted: (_) => _submit(),
                  ),
                  VGap.xxl,
                  AppButton(
                    label: 'Send reset link',
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
