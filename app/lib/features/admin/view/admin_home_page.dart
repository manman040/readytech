import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_card.dart';
import 'package:readytech/core/widgets/upcoming_card.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/features/home/widgets/home_header.dart';

/// Administrator landing inside the mobile app.
///
/// Deliberately minimal. Administration is a desk job - verification queues,
/// dispute evidence, pricing tables and reports need a wide screen - so the
/// real console is the Next.js dashboard in `admin/`, delivered in Phase 9.
/// This screen exists so an admin account has somewhere to land instead of
/// being bounced by the router.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

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
            HomeHeader(profile: state.profile, subtitle: 'Administrator'),
            VGap.xxl,
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.desktop_windows_outlined,
                    size: 20,
                    color: context.colors.onSurfaceVariant,
                  ),
                  HGap.md,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use the admin dashboard',
                          style: context.text.titleSmall,
                        ),
                        VGap.xs,
                        Text(
                          'Verification, disputes, pricing and reports are '
                          'handled in the web console, which is built for a '
                          'wide screen.',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            VGap.xxl,
            const UpcomingCard(
              title: 'Admin console',
              items: [
                Upcoming(
                  Icons.verified_outlined,
                  'Technician verification queue',
                  'Phase 9',
                ),
                Upcoming(
                  Icons.price_change_outlined,
                  'Pricing, fees and commission configuration',
                  'Phase 9',
                ),
                Upcoming(
                  Icons.gavel_outlined,
                  'Disputes, refunds and suspensions',
                  'Phase 9',
                ),
                Upcoming(
                  Icons.insights_outlined,
                  'Marketplace reports',
                  'Phase 9',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
