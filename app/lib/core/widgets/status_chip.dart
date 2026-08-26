import 'package:flutter/material.dart';
import 'package:readytech/core/theme/app_spacing.dart';
import 'package:readytech/core/theme/app_theme.dart';
import 'package:readytech/data/models/service_status.dart';

/// The meaning a chip carries, independent of which colour expresses it.
enum StatusTone { neutral, info, live, success, warning, danger }

/// A compact status label.
///
/// Always renders an icon alongside the text. Colour alone cannot carry the
/// difference between "waiting for part" and "repair complete" for a user with
/// a colour vision deficiency, and it disappears entirely in a screen reader.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    super.key,
    this.icon,
    this.isCompact = false,
  });

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    final (background, foreground) = switch (tone) {
      StatusTone.neutral => (
        semantic.neutralContainer,
        semantic.onNeutralContainer,
      ),
      StatusTone.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
      StatusTone.live => (semantic.liveContainer, semantic.onLiveContainer),
      StatusTone.success => (
        semantic.successContainer,
        semantic.onSuccessContainer,
      ),
      StatusTone.warning => (
        semantic.warningContainer,
        semantic.onWarningContainer,
      ),
      StatusTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? Gap.sm : Gap.md,
          vertical: isCompact ? Gap.xs : Gap.sm - 2,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: Radii.borderSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: isCompact ? 13 : 15, color: foreground),
              const SizedBox(width: Gap.xs + 2),
            ],
            Text(
              label,
              style:
                  (isCompact
                          ? Theme.of(context).textTheme.labelSmall
                          : Theme.of(context).textTheme.labelMedium)
                      ?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

/// A [StatusChip] driven by the service lifecycle.
///
/// Keeping the status-to-appearance mapping here rather than in the enum keeps
/// [ServiceStatus] free of Flutter imports, so the state machine stays testable
/// as plain Dart.
class ServiceStatusChip extends StatelessWidget {
  const ServiceStatusChip({
    required this.status,
    super.key,
    this.forTechnician = false,
    this.isCompact = false,
  });

  final ServiceStatus status;
  final bool forTechnician;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return StatusChip(
      label: forTechnician ? status.technicianLabel : status.customerLabel,
      tone: toneOf(status),
      icon: iconOf(status),
      isCompact: isCompact,
    );
  }

  static StatusTone toneOf(ServiceStatus status) => switch (status) {
    ServiceStatus.requested || ServiceStatus.matching => StatusTone.info,
    ServiceStatus.assigned ||
    ServiceStatus.technicianOnTheWay ||
    ServiceStatus.arrived ||
    ServiceStatus.checkingIn ||
    ServiceStatus.diagnosing ||
    ServiceStatus.repairing => StatusTone.live,
    ServiceStatus.quotationPending ||
    ServiceStatus.quotationSubmitted ||
    ServiceStatus.awaitingCustomerApproval ||
    ServiceStatus.additionalQuotePending ||
    ServiceStatus.waitingForPart ||
    ServiceStatus.paymentPending => StatusTone.warning,
    ServiceStatus.approved ||
    ServiceStatus.completed ||
    ServiceStatus.paid ||
    ServiceStatus.warrantyActive => StatusTone.success,
    ServiceStatus.disputed => StatusTone.danger,
    ServiceStatus.cancelled => StatusTone.neutral,
  };

  static IconData iconOf(ServiceStatus status) => switch (status) {
    ServiceStatus.requested => Icons.receipt_long_outlined,
    ServiceStatus.matching => Icons.radar_outlined,
    ServiceStatus.assigned => Icons.assignment_ind_outlined,
    ServiceStatus.technicianOnTheWay => Icons.navigation_outlined,
    ServiceStatus.arrived => Icons.place_outlined,
    ServiceStatus.checkingIn => Icons.qr_code_scanner_outlined,
    ServiceStatus.diagnosing => Icons.troubleshoot_outlined,
    ServiceStatus.quotationPending => Icons.edit_note_outlined,
    ServiceStatus.quotationSubmitted => Icons.description_outlined,
    ServiceStatus.awaitingCustomerApproval => Icons.pending_actions_outlined,
    ServiceStatus.approved => Icons.check_circle_outline,
    ServiceStatus.repairing => Icons.build_outlined,
    ServiceStatus.waitingForPart => Icons.inventory_2_outlined,
    ServiceStatus.additionalQuotePending => Icons.add_task_outlined,
    ServiceStatus.completed => Icons.task_alt_outlined,
    ServiceStatus.paymentPending => Icons.account_balance_wallet_outlined,
    ServiceStatus.paid => Icons.verified_outlined,
    ServiceStatus.warrantyActive => Icons.shield_outlined,
    ServiceStatus.cancelled => Icons.cancel_outlined,
    ServiceStatus.disputed => Icons.gavel_outlined,
  };
}
