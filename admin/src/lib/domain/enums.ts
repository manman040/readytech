import type { Tone } from './service-status';

/**
 * Labels for the schema's closed vocabularies.
 *
 * Each map's keys must equal the Postgres enum of the same name exactly;
 * `test/domain.test.ts` reads the migrations and fails if a value is added on
 * either side without the other. Where the mobile app already names a value
 * (device types, roles), the wording here is copied from the Dart model so
 * support staff and customers use the same words.
 */

type Labelled<T extends string> = Record<T, { label: string; tone: Tone }>;

/** `user_role` - wording from app/lib/data/models/user_role.dart. */
export const USER_ROLE = {
  customer: { label: 'Customer', tone: 'neutral' },
  technician: { label: 'Technician', tone: 'info' },
  admin: { label: 'Administrator', tone: 'danger' },
} as const satisfies Labelled<string>;
export type UserRole = keyof typeof USER_ROLE;

export const VERIFICATION_STATUS = {
  unsubmitted: { label: 'Not submitted', tone: 'neutral' },
  pending: { label: 'Pending review', tone: 'warning' },
  approved: { label: 'Verified', tone: 'success' },
  rejected: { label: 'Rejected', tone: 'danger' },
  suspended: { label: 'Suspended', tone: 'danger' },
} as const satisfies Labelled<string>;
export type VerificationStatus = keyof typeof VERIFICATION_STATUS;

/** `device_type` - wording from app/lib/data/models/device_type.dart. */
export const DEVICE_TYPE = {
  laptop: { label: 'Laptop', tone: 'neutral' },
  desktop: { label: 'Desktop PC', tone: 'neutral' },
  printer: { label: 'Printer', tone: 'neutral' },
  network_device: { label: 'Router or WiFi', tone: 'neutral' },
  mobile: { label: 'Phone', tone: 'neutral' },
  tablet: { label: 'Tablet', tone: 'neutral' },
  server: { label: 'Server', tone: 'neutral' },
  peripheral: { label: 'Accessory', tone: 'neutral' },
  other: { label: 'Other', tone: 'neutral' },
} as const satisfies Labelled<string>;
export type DeviceType = keyof typeof DEVICE_TYPE;

export const URGENCY_LEVEL = {
  normal: { label: 'Normal', tone: 'neutral' },
  priority: { label: 'Priority', tone: 'warning' },
  emergency: { label: 'Emergency', tone: 'danger' },
} as const satisfies Labelled<string>;

export const MATCHING_MODE = {
  user_selected: { label: 'Customer chose', tone: 'neutral' },
  auto: { label: 'Auto match', tone: 'neutral' },
} as const satisfies Labelled<string>;

export const SERVICE_ACTOR = {
  customer: { label: 'Customer', tone: 'neutral' },
  technician: { label: 'Technician', tone: 'info' },
  system: { label: 'System', tone: 'neutral' },
  admin: { label: 'Administrator', tone: 'danger' },
} as const satisfies Labelled<string>;

export const ASSIGNMENT_STATUS = {
  offered: { label: 'Offered', tone: 'warning' },
  accepted: { label: 'Accepted', tone: 'success' },
  declined: { label: 'Declined', tone: 'neutral' },
  expired: { label: 'Expired', tone: 'neutral' },
  withdrawn: { label: 'Withdrawn', tone: 'neutral' },
} as const satisfies Labelled<string>;

export const QUOTATION_KIND = {
  initial: { label: 'Initial', tone: 'neutral' },
  additional: { label: 'Additional work', tone: 'warning' },
} as const satisfies Labelled<string>;

export const QUOTATION_STATUS = {
  draft: { label: 'Draft', tone: 'neutral' },
  submitted: { label: 'Awaiting decision', tone: 'warning' },
  approved: { label: 'Approved', tone: 'success' },
  declined: { label: 'Declined', tone: 'danger' },
  superseded: { label: 'Superseded', tone: 'neutral' },
  expired: { label: 'Expired', tone: 'neutral' },
} as const satisfies Labelled<string>;

export const QUOTATION_ITEM_KIND = {
  diagnosis: { label: 'Diagnosis', tone: 'neutral' },
  labour: { label: 'Labour', tone: 'neutral' },
  part: { label: 'Part', tone: 'neutral' },
  travel: { label: 'Travel', tone: 'neutral' },
  additional_service: { label: 'Additional service', tone: 'neutral' },
  other: { label: 'Other', tone: 'neutral' },
} as const satisfies Labelled<string>;

export const PAYMENT_PROVIDER = {
  toyyibpay: { label: 'ToyyibPay', tone: 'neutral' },
  manual: { label: 'Manual', tone: 'neutral' },
} as const satisfies Labelled<string>;

export const PAYMENT_STATUS = {
  pending: { label: 'Pending', tone: 'neutral' },
  awaiting_payment: { label: 'Awaiting payment', tone: 'warning' },
  paid: { label: 'Paid', tone: 'success' },
  failed: { label: 'Failed', tone: 'danger' },
  expired: { label: 'Expired', tone: 'neutral' },
  refunded: { label: 'Refunded', tone: 'info' },
  partially_refunded: { label: 'Partly refunded', tone: 'info' },
} as const satisfies Labelled<string>;

export const EARNING_STATUS = {
  pending: { label: 'Pending release', tone: 'warning' },
  released: { label: 'Released', tone: 'success' },
  withheld: { label: 'Withheld', tone: 'danger' },
} as const satisfies Labelled<string>;

export const EVIDENCE_TYPE = {
  before_service: { label: 'Before service', tone: 'neutral' },
  diagnosis: { label: 'Diagnosis', tone: 'neutral' },
  after_service: { label: 'After service', tone: 'neutral' },
  dispute: { label: 'Dispute', tone: 'danger' },
} as const satisfies Labelled<string>;

export const WARRANTY_STATUS = {
  active: { label: 'Active', tone: 'success' },
  expired: { label: 'Expired', tone: 'neutral' },
  claimed: { label: 'Claimed', tone: 'warning' },
  void: { label: 'Void', tone: 'danger' },
} as const satisfies Labelled<string>;

export const DISPUTE_REASON = {
  repair_not_working: { label: 'Repair not working', tone: 'neutral' },
  unexpected_charge: { label: 'Unexpected charge', tone: 'neutral' },
  technician_no_show: { label: 'Technician did not arrive', tone: 'neutral' },
  damage_caused: { label: 'Damage caused', tone: 'neutral' },
  poor_service: { label: 'Poor service', tone: 'neutral' },
  other: { label: 'Other', tone: 'neutral' },
} as const satisfies Labelled<string>;

export const DISPUTE_STATUS = {
  open: { label: 'Open', tone: 'danger' },
  under_review: { label: 'Under review', tone: 'warning' },
  resolved: { label: 'Resolved', tone: 'success' },
  rejected: { label: 'Not upheld', tone: 'neutral' },
} as const satisfies Labelled<string>;
export type DisputeStatus = keyof typeof DISPUTE_STATUS;

/** Every map above, keyed by the Postgres type it mirrors. */
export const ENUM_MIRRORS: Record<string, Record<string, unknown>> = {
  user_role: USER_ROLE,
  verification_status: VERIFICATION_STATUS,
  device_type: DEVICE_TYPE,
  urgency_level: URGENCY_LEVEL,
  matching_mode: MATCHING_MODE,
  service_actor: SERVICE_ACTOR,
  assignment_status: ASSIGNMENT_STATUS,
  quotation_kind: QUOTATION_KIND,
  quotation_status: QUOTATION_STATUS,
  quotation_item_kind: QUOTATION_ITEM_KIND,
  payment_provider: PAYMENT_PROVIDER,
  payment_status: PAYMENT_STATUS,
  earning_status: EARNING_STATUS,
  evidence_type: EVIDENCE_TYPE,
  warranty_status: WARRANTY_STATUS,
  dispute_reason: DISPUTE_REASON,
  dispute_status: DISPUTE_STATUS,
};

/** Looks a value up, degrading to a readable label for a value this build
 * does not know - the same choice the app makes with `fromWire`, so a value
 * added by a later migration still renders instead of breaking a table. */
export function describe(
  map: Record<string, { label: string; tone: Tone }>,
  value: string | null | undefined,
): { label: string; tone: Tone } {
  if (!value) return { label: '—', tone: 'neutral' };
  return map[value] ?? { label: humanise(value), tone: 'neutral' };
}

export function humanise(value: string): string {
  const spaced = value.replace(/[_-]+/g, ' ').toLowerCase().trim();
  return spaced.charAt(0).toUpperCase() + spaced.slice(1);
}
