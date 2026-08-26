import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_button.dart';
import 'package:readytech/core/widgets/upcoming_card.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/features/home/widgets/home_header.dart';

/// The customer's landing screen.
///
/// Phase 1 establishes the shell, the header and the primary call to action.
/// The Get Help flow behind it - problem capture, classification, matching -
/// is built in Phase 2, so the button is present but inert rather than wired to
/// a screen that does not exist yet.
class CustomerHomePage extends StatelessWidget {
  const CustomerHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AuthBloc>().state;
    if (state is! AuthAuthenticated) return const SizedBox.shrink();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            Gap.page,
            Gap.lg,
            Gap.page,
            Gap.huge,
          ),
          children: [
            HomeHeader(profile: state.profile),
            VGap.xxxl,
            Text(
              'What can we help you with?',
              style: context.text.headlineSmall,
            ),
            VGap.sm,
            Text(
              'Describe the problem in your own words. '
              'No technical terms needed.',
              style: context.text.bodyMedium,
            ),
            VGap.xl,
            const AppButton(
              label: 'Get Help',
              icon: Icons.add_rounded,
              // Enabled in Phase 2, when the problem report flow exists.
              onPressed: null,
            ),
            VGap.xxxl,
            const UpcomingCard(
              items: [
                Upcoming(
                  Icons.edit_note_outlined,
                  'Describe a problem by text, voice or photo',
                  'Phase 2',
                ),
                Upcoming(
                  Icons.devices_other_outlined,
                  'My Devices and their service history',
                  'Phase 2',
                ),
                Upcoming(
                  Icons.person_search_outlined,
                  'Top 3 technician matches, or auto match',
                  'Phase 4',
                ),
                Upcoming(
                  Icons.map_outlined,
                  'Live tracking and arrival verification',
                  'Phase 5',
                ),
                Upcoming(
                  Icons.receipt_long_outlined,
                  'Diagnosis, quotation and approval',
                  'Phase 6',
                ),
                Upcoming(
                  Icons.shield_outlined,
                  'Payment, warranty and reviews',
                  'Phase 7-8',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
