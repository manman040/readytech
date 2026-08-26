import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_card.dart';
import 'package:readytech/core/widgets/status_chip.dart';
import 'package:readytech/core/widgets/upcoming_card.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/features/home/widgets/home_header.dart';

/// The technician's landing screen.
///
/// Phase 1 establishes the shell. Availability, job requests and earnings land
/// in Phase 3; the online toggle is shown but inert, because a technician who
/// appears online without the backend knowing would be sent jobs that never
/// arrive.
class TechnicianHomePage extends StatelessWidget {
  const TechnicianHomePage({super.key});

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
            HomeHeader(profile: state.profile, subtitle: 'Technician'),
            VGap.xxl,
            const _AvailabilityCard(),
            VGap.xxl,
            Text('Today', style: context.text.titleMedium),
            VGap.md,
            const _StatRow(),
            VGap.xxl,
            const UpcomingCard(
              items: [
                Upcoming(
                  Icons.verified_user_outlined,
                  'Profile, skills and admin verification',
                  'Phase 3',
                ),
                Upcoming(
                  Icons.toggle_on_outlined,
                  'Go online and receive job requests',
                  'Phase 3',
                ),
                Upcoming(
                  Icons.navigation_outlined,
                  'Navigate, arrive and verify the arrival code',
                  'Phase 5-6',
                ),
                Upcoming(
                  Icons.troubleshoot_outlined,
                  'Diagnosis, evidence and quotations',
                  'Phase 6',
                ),
                Upcoming(
                  Icons.payments_outlined,
                  'Earnings and commission statements',
                  'Phase 7',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Availability', style: context.text.titleSmall),
                VGap.xs,
                Text(
                  'Turn this on to start receiving nearby jobs.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          HGap.md,
          const StatusChip(
            label: 'Offline',
            tone: StatusTone.neutral,
            icon: Icons.circle_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _Stat(label: 'Jobs', value: '0'),
        ),
        HGap.md,
        Expanded(
          child: _Stat(label: 'Earned', value: 'RM0.00'),
        ),
        HGap.md,
        Expanded(
          child: _Stat(label: 'Rating', value: '-'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(Gap.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: context.text.titleLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          VGap.xxs,
          Text(label, style: context.text.labelSmall),
        ],
      ),
    );
  }
}
