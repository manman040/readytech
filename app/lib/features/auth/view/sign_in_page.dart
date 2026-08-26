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
import 'package:readytech/features/auth/bloc/login_cubit.dart';
import 'package:readytech/features/auth/widgets/auth_scaffold.dart';
import 'package:readytech/features/auth/widgets/brand_mark.dart';
import 'package:readytech/routing/routes.dart';

class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LoginCubit(getIt<AuthRepository>()),
      child: const _SignInView(),
    );
  }
}

class _SignInView extends StatefulWidget {
  const _SignInView();

  @override
  State<_SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends State<_SignInView> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    // Dismiss the keyboard first so the error banner is not hidden behind it.
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    unawaited(
      context.read<LoginCubit>().submit(
        email: _email.text,
        password: _password.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LoginCubit, SubmissionState<void>>(
      builder: (context, state) {
        return AuthScaffold(
          showBackButton: false,
          title: 'Welcome back',
          subtitle: 'Sign in to get help with your devices.',
          // Wrap rather than Row: at a large text scale on a narrow phone the
          // prompt and the link do not fit on one line, and a footer that
          // overflows is a footer nobody can tap.
          footer: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Don't have an account?",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              AppButton.text(
                label: 'Create one',
                onPressed: () => context.pushNamed(AppRoute.signUp.name),
              ),
            ],
          ),
          children: [
            const Center(child: BrandMark()),
            VGap.xxxl,
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
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    validator: Validators.email,
                    enabled: !state.isInProgress,
                  ),
                  VGap.xl,
                  AppTextField(
                    label: 'Password',
                    controller: _password,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.password],
                    // Only checks that something was entered. Applying the
                    // sign-up strength rules here would lock out anyone whose
                    // existing password predates them.
                    validator: (value) =>
                        Validators.required(value, field: 'Password'),
                    enabled: !state.isInProgress,
                    onSubmitted: (_) => _submit(),
                  ),
                  VGap.sm,
                  Align(
                    alignment: Alignment.centerRight,
                    child: AppButton.text(
                      label: 'Forgot password?',
                      onPressed: () =>
                          context.pushNamed(AppRoute.forgotPassword.name),
                    ),
                  ),
                  VGap.lg,
                  AppButton(
                    label: 'Sign in',
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
