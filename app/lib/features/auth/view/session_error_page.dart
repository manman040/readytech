import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/state_views.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_event.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';

/// Shown when the session is valid but the profile could not be loaded -
/// typically a cold start with no connection.
///
/// Deliberately not a forced sign-out. The credentials are fine; signing the
/// user out here would make them retype a password to solve a network problem.
class SessionErrorPage extends StatelessWidget {
  const SessionErrorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            final failure = state is AuthProfileUnavailable
                ? state.failure
                : null;

            return Column(
              children: [
                Expanded(
                  child: failure == null
                      ? const AppLoadingView(label: 'Signing you in')
                      : AppErrorState(
                          title: 'We could not load your account',
                          failure: failure,
                          onRetry: () => context.read<AuthBloc>().add(
                            const AuthProfileRequested(),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(Gap.page),
                  child: AppButton.text(
                    label: 'Sign out',
                    isFullWidth: true,
                    onPressed: () => context.read<AuthBloc>().add(
                      const AuthSignOutRequested(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
