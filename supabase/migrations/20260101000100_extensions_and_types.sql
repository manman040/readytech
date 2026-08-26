-- ReadyTech :: extensions and domain types
--
-- Every closed vocabulary in the product is a Postgres enum rather than a text
-- column with a comment. A typo in a status string should be a failed insert,
-- not a service request that silently drops out of every query that filters on
-- status.

create extension if not exists pgcrypto with schema extensions;
create extension if not exists citext with schema extensions;
-- Distance-based matching is a core feature; PostGIS gives us correct
-- great-circle distance and a GIST index instead of a full scan with a
-- hand-rolled haversine.
create extension if not exists postgis with schema extensions;

-- ---------------------------------------------------------------------------
-- Identity
-- ---------------------------------------------------------------------------

create type public.user_role as enum ('customer', 'technician', 'admin');

create type public.verification_status as enum (
  'unsubmitted',
  'pending',
  'approved',
  'rejected',
  'suspended'
);

-- ---------------------------------------------------------------------------
-- Service lifecycle
-- ---------------------------------------------------------------------------

-- Mirrored by ServiceStatus in app/lib/data/models/service_status.dart.
-- The transition table in service_request_status_guard() is the authority;
-- the Dart copy exists only so the client can hide impossible actions.
create type public.service_status as enum (
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
  'DISPUTED'
);

create type public.service_actor as enum (
  'customer',
  'technician',
  'system',
  'admin'
);

create type public.urgency_level as enum ('normal', 'priority', 'emergency');

create type public.matching_mode as enum ('user_selected', 'auto');

create type public.assignment_status as enum (
  'offered',
  'accepted',
  'declined',
  'expired',
  'withdrawn'
);

-- ---------------------------------------------------------------------------
-- Devices and locations
-- ---------------------------------------------------------------------------

create type public.device_type as enum (
  'laptop',
  'desktop',
  'printer',
  'network_device',
  'mobile',
  'tablet',
  'server',
  'peripheral',
  'other'
);

create type public.address_label as enum ('home', 'office', 'other');

-- ---------------------------------------------------------------------------
-- Money
-- ---------------------------------------------------------------------------

create type public.quotation_kind as enum ('initial', 'additional');

create type public.quotation_status as enum (
  'draft',
  'submitted',
  'approved',
  'declined',
  'superseded',
  'expired'
);

create type public.quotation_item_kind as enum (
  'diagnosis',
  'labour',
  'part',
  'travel',
  'additional_service',
  'other'
);

create type public.payment_provider as enum ('toyyibpay', 'manual');

create type public.payment_status as enum (
  'pending',
  'awaiting_payment',
  'paid',
  'failed',
  'expired',
  'refunded',
  'partially_refunded'
);

create type public.earning_status as enum ('pending', 'released', 'withheld');

-- ---------------------------------------------------------------------------
-- Trust and safety
-- ---------------------------------------------------------------------------

create type public.evidence_type as enum (
  'before_service',
  'diagnosis',
  'after_service',
  'dispute'
);

create type public.warranty_status as enum (
  'active',
  'expired',
  'claimed',
  'void'
);

create type public.dispute_reason as enum (
  'repair_not_working',
  'unexpected_charge',
  'technician_no_show',
  'damage_caused',
  'poor_service',
  'other'
);

create type public.dispute_status as enum (
  'open',
  'under_review',
  'resolved',
  'rejected'
);

-- ---------------------------------------------------------------------------
-- Communication
-- ---------------------------------------------------------------------------

create type public.message_kind as enum ('text', 'image', 'system');

create type public.notification_type as enum (
  'technician_matched',
  'technician_accepted',
  'technician_on_the_way',
  'technician_arrived',
  'diagnosis_completed',
  'quotation_submitted',
  'quotation_approved',
  'additional_quotation_required',
  'repair_started',
  'repair_completed',
  'payment_completed',
  'warranty_reminder',
  'new_message',
  'job_cancelled',
  'job_offer',
  'verification_updated',
  'dispute_updated'
);
