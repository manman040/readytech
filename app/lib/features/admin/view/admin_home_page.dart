import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:readytech/core/extensions/context_x.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/widgets/app_card.dart';
import 'package:readytech/features/auth/bloc/auth_bloc.dart';
import 'package:readytech/features/auth/bloc/auth_state.dart';
import 'package:readytech/features/home/widgets/home_header.dart';

/// Administrator landing inside the mobile app.
///
/// Deliberately minimal. Administration is a desk job - verification queues,
/// dispute evidence, pricing tables and reports need a wide screen - so the
/// real console is the Next.js dashboard in `admin/`. This screen exists so an
/// admin account has somewhere to land instead of being bounced by the router,
/// and tells them where the work is.
class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  static const List<(IconData, String)> _areas = [
    (Icons.verified_outlined, 'Technician verification and suspension'),
    (Icons.gavel_outlined, 'Disputes, cancellations and job oversight'),
    (Icons.price_change_outlined, 'Service catalogue and pricing'),
    (Icons.manage_accounts_outlined, 'Accounts and roles'),
    (Icons.shield_outlined, 'Moderation and the audit log'),
  ];

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
                          'Use the admin console',
                          style: context.text.titleSmall,
                        ),
                        VGap.xs,
                        Text(
                          'Sign in to the ReadyTech admin console on a '
                          'computer with this same email and password. It is '
                          'built for a wide screen.',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            VGap.xxl,
            Text('In the console', style: context.text.titleSmall),
            VGap.md,
            for (final (icon, label) in _areas)
              Padding(
                padding: const EdgeInsets.only(bottom: Gap.md),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: context.colors.onSurfaceVariant,
                    ),
                    HGap.md,
                    Expanded(
                      child: Text(label, style: context.text.bodyMedium),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
