-- ReadyTech :: service requests
--
-- The centre of the product. Every other table in the service lifecycle hangs
-- off this one, and its `status` column is the single source of truth for where
-- a job has got to. Status is never advanced by a client writing a string: the
-- guard trigger in 20260101001200_lifecycle.sql rejects any move that is not in
-- the transition table.

create table public.service_requests (
  id uuid primary key default extensions.gen_random_uuid(),

  -- Human-readable identifier for support conversations. Nobody can read a
  -- UUID down the phone.
  reference text not null unique,

  customer_id uuid not null references public.profiles (id) on delete restrict,
  device_id uuid references public.devices (id) on delete set null,
  category_id uuid references public.service_categories (id) on delete set null,
  assigned_technician_id uuid
    references public.technician_profiles (id) on delete set null,

  -- What the customer actually said, kept verbatim. The classifier's output
  -- goes in the summary fields beside it; it never overwrites the original.
  problem_description text not null,
  problem_summary text,
  classified_device_type public.device_type,
  classification_confidence numeric(4, 3),
  -- 'rule_based' now, 'ai' later. Recorded so a bad classification can be
  -- traced to the thing that made it.
  classified_by text,

  urgency public.urgency_level not null default 'normal',
  status public.service_status not null default 'REQUESTED',
  matching_mode public.matching_mode not null default 'user_selected',

  -- Where the work happens. Exposure is controlled by policy, not by leaving
  -- the column out: technicians see the coordinates only once they hold the
  -- job, and the street address only once they have checked in.
  service_latitude numeric(9, 6) not null,
  service_longitude numeric(9, 6) not null,
  service_location extensions.geography(Point, 4326)
    generated always as (
      extensions.st_setsrid(
        extensions.st_makepoint(
          service_longitude::float8,
          service_latitude::float8
        ),
        4326
      )::extensions.geography
    ) stored,
  service_address text not null,
  address_directions text,
  contact_phone text,

  -- Proves the technician is standing in front of the customer before any
  -- work, evidence or fee is recorded against the job.
  arrival_code text,
  arrival_code_verified_at timestamptz,

  -- The range shown before diagnosis. Deliberately a range: an exact number
  -- before anyone has looked at the device would be a promise ReadyTech
  -- cannot keep.
  estimated_total_min_sen bigint,
  estimated_total_max_sen bigint,
  estimated_distance_km numeric(6, 2),
  estimated_eta_minutes integer,

  requested_at timestamptz not null default now(),
  matched_at timestamptz,
  assigned_at timestamptz,
  arrived_at timestamptz,
  diagnosis_at timestamptz,
  approved_at timestamptz,
  completed_at timestamptz,
  paid_at timestamptz,
  cancelled_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint service_requests_description_length
    check (char_length(problem_description) between 10 and 2000),
  constraint service_requests_latitude_range
    check (service_latitude between -90 and 90),
  constraint service_requests_longitude_range
    check (service_longitude between -180 and 180),
  constraint service_requests_estimate_ordered
    check (
      num_nulls(estimated_total_min_sen, estimated_total_max_sen) = 2
      or (
        estimated_total_min_sen >= 0
        and estimated_total_max_sen >= estimated_total_min_sen
      )
    ),
  constraint service_requests_arrival_code_shape
    check (arrival_code is null or arrival_code ~ '^[0-9]{4}$'),
  constraint service_requests_confidence_range
    check (
      classification_confidence is null
      or classification_confidence between 0 and 1
    )
);

comment on table public.service_requests is
  'One job. Rows are never deleted - a cancelled or disputed job stays on the '
  'record, which is what makes a service history trustworthy.';

-- A customer may only have one live job at a time. Enforced by a partial unique
-- index rather than by application logic, because "check then insert" from two
-- devices at once is exactly the race that produces a duplicate booking.
create unique index service_requests_one_active_per_customer_idx
  on public.service_requests (customer_id)
  where status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED');

-- The same guarantee from the other side: a technician cannot be committed to
-- two jobs at once.
create unique index service_requests_one_active_per_technician_idx
  on public.service_requests (assigned_technician_id)
  where assigned_technician_id is not null
    and status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED');

create index service_requests_customer_idx
  on public.service_requests (customer_id, created_at desc);

create index service_requests_technician_idx
  on public.service_requests (assigned_technician_id, created_at desc)
  where assigned_technician_id is not null;

create index service_requests_status_idx
  on public.service_requests (status, created_at desc);

create index service_requests_location_idx
  on public.service_requests using gist (service_location);

create trigger service_requests_set_updated_at
  before update on public.service_requests
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- service_request_items
-- ---------------------------------------------------------------------------

-- Answers to the follow-up questions. Stored as rows rather than a jsonb blob
-- so a category's questions can be reported on across jobs.
create table public.service_request_items (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  question_key text not null,
  question_text text not null,
  answer_text text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),

  unique (request_id, question_key)
);

create index service_request_items_request_idx
  on public.service_request_items (request_id, sort_order);

-- ---------------------------------------------------------------------------
-- service_status_history
-- ---------------------------------------------------------------------------

-- Append-only audit of the lifecycle. Written by a trigger, not by callers, so
-- it cannot disagree with the status column it describes.
create table public.service_status_history (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  from_status public.service_status,
  to_status public.service_status not null,
  actor_id uuid references public.profiles (id) on delete set null,
  actor_role public.service_actor not null,
  reason text,
  created_at timestamptz not null default now()
);

create index service_status_history_request_idx
  on public.service_status_history (request_id, created_at);

-- ---------------------------------------------------------------------------
-- technician_assignments
-- ---------------------------------------------------------------------------

-- The offer ledger. Auto-match walks candidates in rank order and records each
-- offer here, which is also where the response-rate statistics come from.
create table public.technician_assignments (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  technician_id uuid not null
    references public.technician_profiles (id) on delete cascade,

  status public.assignment_status not null default 'offered',
  rank integer not null default 0,
  -- The computed match score. Never exposed to customers or technicians;
  -- showing it would invite gaming the ranking.
  score numeric(6, 2),
  distance_km numeric(6, 2),
  eta_minutes integer,

  offered_at timestamptz not null default now(),
  expires_at timestamptz not null,
  responded_at timestamptz,
  decline_reason text,

  unique (request_id, technician_id)
);

-- Only one technician can hold an accepted offer on a request. This is the
-- constraint that makes double assignment impossible even if two acceptances
-- arrive in the same millisecond.
create unique index technician_assignments_single_acceptance_idx
  on public.technician_assignments (request_id)
  where status = 'accepted';

create index technician_assignments_technician_idx
  on public.technician_assignments (technician_id, status, offered_at desc);

create index technician_assignments_open_offers_idx
  on public.technician_assignments (expires_at)
  where status = 'offered';

-- ---------------------------------------------------------------------------
-- Reference numbers and arrival codes
-- ---------------------------------------------------------------------------

create sequence public.service_reference_seq;

create or replace function public.generate_service_reference()
returns text
language sql
volatile
as $$
  select 'RT-' || to_char(now(), 'YY') || '-' ||
         lpad(nextval('public.service_reference_seq')::text, 6, '0');
$$;

create or replace function public.service_requests_set_defaults()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  entropy bytea;
begin
  if new.reference is null or new.reference = '' then
    new.reference := public.generate_service_reference();
  end if;

  -- Drawn from pgcrypto rather than random(), because this code is the only
  -- thing standing between a stranger at the door and a check-in, and
  -- random() is a predictable PRNG.
  if new.arrival_code is null then
    entropy := extensions.gen_random_bytes(2);
    new.arrival_code := lpad(
      (((get_byte(entropy, 0) * 256) + get_byte(entropy, 1)) % 10000)::text,
      4,
      '0'
    );
  end if;

  return new;
end;
$$;

create trigger service_requests_defaults
  before insert on public.service_requests
  for each row execute function public.service_requests_set_defaults();
