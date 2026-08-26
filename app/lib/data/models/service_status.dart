/// Who is permitted to drive a status transition.
///
/// The backend is the authority: every transition is re-checked by a Postgres
/// trigger against the same table encoded here. This copy exists so the client
/// can hide buttons it knows will be rejected, never so it can grant itself a
/// transition.
enum ServiceActor { customer, technician, system, admin }

/// The lifecycle of a single service request.
///
/// Statuses are a closed set. Nothing in ReadyTech may write a free-form status
/// string: the column is a Postgres enum, the transition table below is
/// mirrored by a database trigger, and an illegal move is rejected with
/// SQLSTATE RT409.
enum ServiceStatus {
  /// Customer submitted the problem; matching has not started.
  requested('REQUESTED'),

  /// Searching for and ranking eligible technicians.
  matching('MATCHING'),

  /// A technician accepted and is exclusively assigned to this job.
  assigned('ASSIGNED'),

  /// Technician is travelling to the service location.
  technicianOnTheWay('TECHNICIAN_ON_THE_WAY'),

  /// Technician reports being at the location; not yet verified.
  arrived('ARRIVED'),

  /// Arrival code accepted; before-service evidence is being captured.
  checkingIn('CHECKING_IN'),

  /// Technician is investigating the fault.
  diagnosing('DIAGNOSING'),

  /// Diagnosis recorded; technician is preparing a quotation.
  quotationPending('QUOTATION_PENDING'),

  /// Technician has submitted a quotation.
  quotationSubmitted('QUOTATION_SUBMITTED'),

  /// Quotation is in front of the customer.
  awaitingCustomerApproval('AWAITING_CUSTOMER_APPROVAL'),

  /// Customer approved the quotation. Repair may begin.
  approved('APPROVED'),

  /// Repair in progress.
  repairing('REPAIRING'),

  /// Repair paused pending a spare part.
  waitingForPart('WAITING_FOR_PART'),

  /// Extra work was found; a supplementary quotation awaits approval.
  additionalQuotePending('ADDITIONAL_QUOTE_PENDING'),

  /// Work finished and confirmed by the customer.
  completed('COMPLETED'),

  /// Awaiting settlement through the payment provider.
  paymentPending('PAYMENT_PENDING'),

  /// Payment verified server side.
  paid('PAID'),

  /// Warranty issued; the job is closed.
  warrantyActive('WARRANTY_ACTIVE'),

  /// Ended before completion. Retained for the record, never deleted.
  cancelled('CANCELLED'),

  /// Under review by an administrator.
  disputed('DISPUTED')
  ;

  const ServiceStatus(this.wireName);

  /// The value stored in Postgres and sent over the wire.
  final String wireName;

  static ServiceStatus? tryParse(String? value) {
    if (value == null) return null;
    for (final status in ServiceStatus.values) {
      if (status.wireName == value) return status;
    }
    return null;
  }

  /// Statuses this one may legally move to, mapped to the actors allowed to
  /// make the move.
  Map<ServiceStatus, Set<ServiceActor>> get allowedTransitions =>
      _transitions[this] ?? const {};

  bool canTransitionTo(ServiceStatus next) =>
      allowedTransitions.containsKey(next);

  /// Whether [actor] specifically may perform the move to [next].
  bool canBeMovedBy(ServiceActor actor, ServiceStatus next) =>
      allowedTransitions[next]?.contains(actor) ?? false;

  /// No further transitions are possible.
  bool get isTerminal => allowedTransitions.isEmpty;

  /// The job is live and should be surfaced as the customer's active service.
  ///
  /// This is the same set the database uses to decide whether a job occupies a
  /// customer's or a technician's active slot. Defining it as "not terminal"
  /// instead would drift from the backend the moment a closing status is added,
  /// and the home screen would start promoting finished jobs.
  bool get isActive => !_closedStatuses.contains(this);

  /// A technician is committed to this job.
  bool get hasAssignedTechnician => _assignedStatuses.contains(this);

  /// The technician has been checked in on site, which is the point at which
  /// the exact service address stops being sensitive.
  bool get isOnSite => _onSiteStatuses.contains(this);

  /// Short label for the customer-facing UI.
  String get customerLabel => switch (this) {
    requested => 'Request received',
    matching => 'Finding a technician',
    assigned => 'Technician assigned',
    technicianOnTheWay => 'On the way',
    arrived => 'Technician arrived',
    checkingIn => 'Checking in',
    diagnosing => 'Diagnosing',
    quotationPending => 'Preparing quotation',
    quotationSubmitted => 'Quotation ready',
    awaitingCustomerApproval => 'Your approval needed',
    approved => 'Approved',
    repairing => 'Repair in progress',
    waitingForPart => 'Waiting for part',
    additionalQuotePending => 'Extra work needs approval',
    completed => 'Completed',
    paymentPending => 'Payment pending',
    paid => 'Paid',
    warrantyActive => 'Under warranty',
    cancelled => 'Cancelled',
    disputed => 'Under review',
  };

  /// Short label for the technician-facing UI, where the same state reads
  /// differently - "Your approval needed" is the customer's job, not theirs.
  String get technicianLabel => switch (this) {
    awaitingCustomerApproval => 'Awaiting customer approval',
    additionalQuotePending => 'Awaiting approval for extra work',
    paymentPending => 'Awaiting customer payment',
    _ => customerLabel,
  };
}

/// Statuses in which a job no longer occupies an active slot.
///
/// Mirrors the exclusion list on `service_requests_one_active_per_customer_idx`
/// and `active_service_request()`. A disputed job is included: a dispute can
/// take days to resolve, and blocking a customer from booking anything else in
/// the meantime would punish them for raising it.
const Set<ServiceStatus> _closedStatuses = {
  ServiceStatus.completed,
  ServiceStatus.paid,
  ServiceStatus.warrantyActive,
  ServiceStatus.cancelled,
  ServiceStatus.disputed,
};

/// Statuses in which a technician is exclusively bound to the request.
const Set<ServiceStatus> _assignedStatuses = {
  ServiceStatus.assigned,
  ServiceStatus.technicianOnTheWay,
  ServiceStatus.arrived,
  ServiceStatus.checkingIn,
  ServiceStatus.diagnosing,
  ServiceStatus.quotationPending,
  ServiceStatus.quotationSubmitted,
  ServiceStatus.awaitingCustomerApproval,
  ServiceStatus.approved,
  ServiceStatus.repairing,
  ServiceStatus.waitingForPart,
  ServiceStatus.additionalQuotePending,
  ServiceStatus.completed,
  ServiceStatus.paymentPending,
  ServiceStatus.paid,
};

const Set<ServiceStatus> _onSiteStatuses = {
  ServiceStatus.checkingIn,
  ServiceStatus.diagnosing,
  ServiceStatus.quotationPending,
  ServiceStatus.quotationSubmitted,
  ServiceStatus.awaitingCustomerApproval,
  ServiceStatus.approved,
  ServiceStatus.repairing,
  ServiceStatus.waitingForPart,
  ServiceStatus.additionalQuotePending,
};

/// Actors permitted to cancel while the job has not yet started on site.
const Set<ServiceActor> _cancellable = {
  ServiceActor.customer,
  ServiceActor.admin,
};

/// The authoritative transition table.
///
/// Mirrored by `service_request_status_guard()` in
/// `supabase/migrations/..._functions_triggers.sql`. Changing one without the
/// other is a bug; the state machine test asserts the shape of this table.
const Map<ServiceStatus, Map<ServiceStatus, Set<ServiceActor>>> _transitions = {
  ServiceStatus.requested: {
    ServiceStatus.matching: {ServiceActor.system},
    ServiceStatus.assigned: {ServiceActor.system},
    ServiceStatus.cancelled: _cancellable,
  },
  ServiceStatus.matching: {
    ServiceStatus.assigned: {ServiceActor.system},
    // No technician accepted within the search window.
    ServiceStatus.cancelled: {ServiceActor.system, ..._cancellable},
  },
  ServiceStatus.assigned: {
    ServiceStatus.technicianOnTheWay: {ServiceActor.technician},
    // Technician withdrew; matching starts again.
    ServiceStatus.matching: {ServiceActor.system, ServiceActor.admin},
    ServiceStatus.cancelled: {ServiceActor.technician, ..._cancellable},
  },
  ServiceStatus.technicianOnTheWay: {
    ServiceStatus.arrived: {ServiceActor.technician},
    ServiceStatus.matching: {ServiceActor.system, ServiceActor.admin},
    ServiceStatus.cancelled: {ServiceActor.technician, ..._cancellable},
  },
  ServiceStatus.arrived: {
    // Only after the customer's arrival code is verified.
    ServiceStatus.checkingIn: {ServiceActor.technician},
    ServiceStatus.cancelled: {ServiceActor.technician, ..._cancellable},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.checkingIn: {
    ServiceStatus.diagnosing: {ServiceActor.technician},
    ServiceStatus.cancelled: {ServiceActor.technician, ..._cancellable},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.diagnosing: {
    ServiceStatus.quotationPending: {ServiceActor.technician},
    ServiceStatus.cancelled: {ServiceActor.technician, ..._cancellable},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.quotationPending: {
    ServiceStatus.quotationSubmitted: {ServiceActor.technician},
    ServiceStatus.cancelled: {ServiceActor.technician, ..._cancellable},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.quotationSubmitted: {
    ServiceStatus.awaitingCustomerApproval: {ServiceActor.system},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.awaitingCustomerApproval: {
    ServiceStatus.approved: {ServiceActor.customer},
    // Declining the quotation ends the job; the diagnosis fee still applies.
    ServiceStatus.cancelled: {ServiceActor.customer, ServiceActor.admin},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.approved: {
    ServiceStatus.repairing: {ServiceActor.technician},
    ServiceStatus.cancelled: {ServiceActor.admin},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.repairing: {
    ServiceStatus.waitingForPart: {ServiceActor.technician},
    ServiceStatus.additionalQuotePending: {ServiceActor.technician},
    ServiceStatus.completed: {ServiceActor.customer},
    ServiceStatus.cancelled: {ServiceActor.admin},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.waitingForPart: {
    ServiceStatus.repairing: {ServiceActor.technician},
    ServiceStatus.cancelled: {ServiceActor.admin, ServiceActor.customer},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.additionalQuotePending: {
    // Approved: the extra work joins the payable total.
    ServiceStatus.repairing: {ServiceActor.customer},
    ServiceStatus.cancelled: {ServiceActor.admin, ServiceActor.customer},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.completed: {
    ServiceStatus.paymentPending: {ServiceActor.system},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.paymentPending: {
    // Only ever set by the payment webhook, never by a client.
    ServiceStatus.paid: {ServiceActor.system},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.paid: {
    ServiceStatus.warrantyActive: {ServiceActor.system},
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.warrantyActive: {
    ServiceStatus.disputed: {ServiceActor.customer, ServiceActor.admin},
  },
  ServiceStatus.disputed: {
    // Resolution outcomes, administrator only.
    ServiceStatus.warrantyActive: {ServiceActor.admin},
    ServiceStatus.paid: {ServiceActor.admin},
    ServiceStatus.repairing: {ServiceActor.admin},
    ServiceStatus.cancelled: {ServiceActor.admin},
  },
  ServiceStatus.cancelled: {},
};
