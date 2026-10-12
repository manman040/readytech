/**
 * The service lifecycle, as the console renders it.
 *
 * Mirrors `service_status` in Postgres and `ServiceStatus` in
 * app/lib/data/models/service_status.dart. Like the Dart copy, this never
 * grants anything: which moves an administrator may make is read from the
 * `service_status_transitions` table at runtime, and the status guard trigger
 * has the final word. `test/domain.test.ts` fails if this list drifts from the
 * migration.
 */

export const SERVICE_STATUSES = [
  'REQUESTED',
  'MATCHING',
  'ASSIGNED',
  'TECHNICIAN_ON_THE_WAY',
  'ARRIVED',
  'CHECKING_IN',
  'DIAGNOSING',
  'QUOTATION_PENDING',
  'QUOTATION_SUBMITTED',
  'AWAITING_CUSTOMER_APPROVAL',
  'APPROVED',
  'REPAIRING',
  'WAITING_FOR_PART',
  'ADDITIONAL_QUOTE_PENDING',
  'COMPLETED',
  'PAYMENT_PENDING',
  'PAID',
  'WARRANTY_ACTIVE',
  'CANCELLED',
  'DISPUTED',
] as const;

export type ServiceStatus = (typeof SERVICE_STATUSES)[number];

export type Tone = 'info' | 'live' | 'warning' | 'success' | 'danger' | 'neutral';

/** What the customer sees in the app - shown in the console so support staff
 * can say exactly what the person on the phone is looking at. */
export const CUSTOMER_LABEL: Record<ServiceStatus, string> = {
  REQUESTED: 'Request received',
  MATCHING: 'Finding a technician',
  ASSIGNED: 'Technician assigned',
  TECHNICIAN_ON_THE_WAY: 'On the way',
  ARRIVED: 'Technician arrived',
  CHECKING_IN: 'Checking in',
  DIAGNOSING: 'Diagnosing',
  QUOTATION_PENDING: 'Preparing quotation',
  QUOTATION_SUBMITTED: 'Quotation ready',
  AWAITING_CUSTOMER_APPROVAL: 'Your approval needed',
  APPROVED: 'Approved',
  REPAIRING: 'Repair in progress',
  WAITING_FOR_PART: 'Waiting for part',
  ADDITIONAL_QUOTE_PENDING: 'Extra work needs approval',
  COMPLETED: 'Completed',
  PAYMENT_PENDING: 'Payment pending',
  PAID: 'Paid',
  WARRANTY_ACTIVE: 'Under warranty',
  CANCELLED: 'Cancelled',
  DISPUTED: 'Under review',
};

/** The console's own wording. Starts from the technician copy in the app,
 * which already names the state from a neutral point of view, and calls a
 * dispute a dispute: "Under review" is a kindness to the customer, not a
 * description an administrator can act on. */
export const ADMIN_LABEL: Record<ServiceStatus, string> = {
  ...CUSTOMER_LABEL,
  AWAITING_CUSTOMER_APPROVAL: 'Awaiting customer approval',
  ADDITIONAL_QUOTE_PENDING: 'Awaiting approval for extra work',
  PAYMENT_PENDING: 'Awaiting customer payment',
  DISPUTED: 'Disputed',
};

/** Same grouping as `ServiceStatusChip.toneOf` in the app. */
export const STATUS_TONE: Record<ServiceStatus, Tone> = {
  REQUESTED: 'info',
  MATCHING: 'info',
  ASSIGNED: 'live',
  TECHNICIAN_ON_THE_WAY: 'live',
  ARRIVED: 'live',
  CHECKING_IN: 'live',
  DIAGNOSING: 'live',
  REPAIRING: 'live',
  QUOTATION_PENDING: 'warning',
  QUOTATION_SUBMITTED: 'warning',
  AWAITING_CUSTOMER_APPROVAL: 'warning',
  ADDITIONAL_QUOTE_PENDING: 'warning',
  WAITING_FOR_PART: 'warning',
  PAYMENT_PENDING: 'warning',
  APPROVED: 'success',
  COMPLETED: 'success',
  PAID: 'success',
  WARRANTY_ACTIVE: 'success',
  DISPUTED: 'danger',
  CANCELLED: 'neutral',
};

/** Statuses in which a job no longer occupies an active slot. Mirrors the
 * exclusion list on the one-live-job indexes and `active_service_request()`. */
export const CLOSED_STATUSES: ReadonlySet<ServiceStatus> = new Set([
  'COMPLETED',
  'PAID',
  'WARRANTY_ACTIVE',
  'CANCELLED',
  'DISPUTED',
]);

export function isServiceStatus(value: unknown): value is ServiceStatus {
  return typeof value === 'string' && (SERVICE_STATUSES as readonly string[]).includes(value);
}

export function isActive(status: ServiceStatus): boolean {
  return !CLOSED_STATUSES.has(status);
}

/** Groups used by the job list filter. */
export const STATUS_GROUPS: Record<string, { label: string; statuses: ServiceStatus[] }> = {
  active: {
    label: 'Active',
    statuses: SERVICE_STATUSES.filter((s) => !CLOSED_STATUSES.has(s)),
  },
  matching: { label: 'Matching', statuses: ['REQUESTED', 'MATCHING'] },
  attention: {
    label: 'Needs attention',
    statuses: ['AWAITING_CUSTOMER_APPROVAL', 'ADDITIONAL_QUOTE_PENDING', 'WAITING_FOR_PART', 'PAYMENT_PENDING', 'DISPUTED'],
  },
  disputed: { label: 'Disputed', statuses: ['DISPUTED'] },
  finished: { label: 'Finished', statuses: ['COMPLETED', 'PAID', 'WARRANTY_ACTIVE'] },
  cancelled: { label: 'Cancelled', statuses: ['CANCELLED'] },
};
