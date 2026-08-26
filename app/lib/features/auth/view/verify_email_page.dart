import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/bloc/submission_state.dart';
import 'package:readytech/core/di/injector.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/data/repositories/auth_repository.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_event.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/features/auth/bloc/email_verification_cubit.dart';
import 'package:readytech/features/auth/widgets/auth_scaffold.dart';
import 'package:readytech/features/auth/widgets/brand_mark.dart';

/// Shown while an account exists but its email address is unconfirmed.
///
/// The app never decides for itself that verification is done. "I have
/// verified" exchanges the refresh token for a new one and reads the answer off
/// the backend; if the address is still unconfirmed the user stays here.
class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => EmailVerificationCubit(getIt<AuthRepository>()),
      child: const _VerifyEmailView(),
    );
  }
}

class _VerifyEmailView extends StatelessWidget {
  const _VerifyEmailView();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final email = authState is AuthEmailVerificationRequired
        ? authState.email
        : '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.page),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child:
                  BlocConsumer<
                    EmailVerificationCubit,
                    SubmissionState<VerificationAction>
                  >(
                    listener: (context, state) {
                      if (state.isSuccess &&
                          state.value == VerificationAction.resent) {
                        context.showSnack(
                          'Verification email sent.',
                          icon: Icons.mark_email_read_outlined,
                        );
                        context.read<EmailVerificationCubit>().reset();
                      }
                    },
                    builder: (context, state) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(
                            child: BrandMark(size: 64, showLiveDot: false),
                          ),
                          VGap.xxxl,
                          Text(
                            'Verify your email',
                            style: context.text.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          VGap.md,
                          Text(
                            email.isEmpty
                                ? 'We sent a verification link to your email '
                                      'address. Open it to activate your account.'
                                : 'We sent a verification link to $email. '
                                      'Open it to activate your account.',
                            style: context.text.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          if (state.isFailure) ...[
                            VGap.xl,
                            AuthErrorBanner(message: state.failure!.message),
                          ],
                          VGap.xxxl,
                          AppButton(
                            label: 'I have verified',
                            icon: Icons.refresh_rounded,
                            isBusy: state.isInProgress,
                            onPressed: () => context
                                .read<EmailVerificationCubit>()
                                .checkVerification(),
                          ),
                          VGap.md,
                          AppButton.secondary(
                            label: 'Resend email',
                            onPressed: email.isEmpty || state.isInProgress
                                ? null
                                : () => context
                                      .read<EmailVerificationCubit>()
                                      .resend(email),
                          ),
                          VGap.lg,
                          AppButton.text(
                            label: 'Use a different account',
                            isFullWidth: true,
                            onPressed: () => context.read<AuthBloc>().add(
                              const AuthSignOutRequested(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
