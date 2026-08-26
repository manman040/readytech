-- ReadyTech :: evidence, warranty, reviews, disputes, cancellations
--
-- These are the tables that make the marketplace trustworthy after the fact:
-- what the device looked like before and after, what was promised, what the
-- customer thought, and what happened when something went wrong.

-- ---------------------------------------------------------------------------
-- service_evidence
-- ---------------------------------------------------------------------------

create table public.service_evidence (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  type public.evidence_type not null,

  -- Object key in the private service-evidence bucket. Not a URL: access is
  -- granted per request through a signed URL, so a leaked link is not a
  -- permanent public window into someone's home or office.
  storage_path text not null,
  caption text,
  uploaded_by uuid not null references public.profiles (id) on delete restrict,
  captured_at timestamptz not null default now(),
  created_at timestamptz not null default now(),

  unique (request_id, storage_path)
);

comment on table public.service_evidence is
  'Append-only. Evidence that can be deleted after a dispute is raised is not '
  'evidence.';

create index service_evidence_request_idx
  on public.service_evidence (request_id, type, created_at);

-- ---------------------------------------------------------------------------
-- service_checklists
-- ---------------------------------------------------------------------------

create table public.service_checklists (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  label text not null,
  is_passed boolean,
  notes text,
  sort_order integer not null default 0,
  checked_at timestamptz,

  unique (request_id, label)
);

create index service_checklists_request_idx
  on public.service_checklists (request_id, sort_order);

-- ---------------------------------------------------------------------------
-- warranties
-- ---------------------------------------------------------------------------

create table public.warranties (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete restrict,
  quotation_id uuid references public.quotations (id) on delete set null,

  -- What is actually covered, in the customer's words rather than a category
  -- name: "Display cable replacement", not "Hardware".
  covered_work text not null,
  days integer not null,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  terms text,
  status public.warranty_status not null default 'active',

  claimed_at timestamptz,
  claim_request_id uuid
    references public.service_requests (id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (request_id),
  constraint warranties_days_sane check (days between 0 and 730),
  constraint warranties_period_ordered check (expires_at > starts_at)
);

create index warranties_expiry_idx
  on public.warranties (expires_at)
  where status = 'active';

create index warranties_request_idx on public.warranties (request_id);

create trigger warranties_set_updated_at
  before update on public.warranties
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- reviews
-- ---------------------------------------------------------------------------

create table public.reviews (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  customer_id uuid not null references public.profiles (id) on delete cascade,
  technician_id uuid not null
    references public.technician_profiles (id) on delete cascade,

  rating_overall smallint not null,
  rating_quality smallint,
  rating_professionalism smallint,
  rating_punctuality smallint,
  rating_pricing smallint,
  comment text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  -- One review per job. This is what stops a customer from repeatedly rating
  -- the same service to move a technician's average.
  unique (request_id),

  constraint reviews_overall_range check (rating_overall between 1 and 5),
  constraint reviews_component_ranges check (
    (rating_quality is null or rating_quality between 1 and 5)
    and (rating_professionalism is null or rating_professionalism between 1 and 5)
    and (rating_punctuality is null or rating_punctuality between 1 and 5)
    and (rating_pricing is null or rating_pricing between 1 and 5)
  ),
  constraint reviews_comment_length
    check (comment is null or char_length(comment) <= 2000)
);

create index reviews_technician_idx
  on public.reviews (technician_id, created_at desc);

create trigger reviews_set_updated_at
  before update on public.reviews
  for each row execute function public.set_updated_at();

-- Keeps the denormalised reputation on technician_profiles in step. Recomputed
-- from the table rather than incremented, so an edited or removed review can
-- never leave the average drifting.
create or replace function public.refresh_technician_rating()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target uuid := coalesce(new.technician_id, old.technician_id);
begin
  update public.technician_profiles t
     set rating_average = coalesce(stats.average, 0),
         rating_count = coalesce(stats.total, 0)
    from (
      select round(avg(rating_overall)::numeric, 2) as average,
             count(*) as total
        from public.reviews
       where technician_id = target
    ) as stats
   where t.id = target;

  return null;
end;
$$;

create trigger reviews_refresh_rating
  after insert or update or delete on public.reviews
  for each row execute function public.refresh_technician_rating();

-- ---------------------------------------------------------------------------
-- disputes
-- ---------------------------------------------------------------------------

create table public.disputes (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete restrict,
  raised_by uuid not null references public.profiles (id) on delete restrict,

  reason public.dispute_reason not null,
  description text not null,
  status public.dispute_status not null default 'open',

  resolution text,
  resolved_by uuid references public.profiles (id) on delete set null,
  resolved_at timestamptz,
  refund_amount_sen bigint not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint disputes_description_length
    check (char_length(description) between 10 and 4000),
  constraint disputes_refund_non_negative check (refund_amount_sen >= 0),
  constraint disputes_resolved_has_detail check (
    status not in ('resolved', 'rejected')
    or (resolved_by is not null and resolved_at is not null
        and resolution is not null)
  )
);

create index disputes_status_idx on public.disputes (status, created_at);
create index disputes_request_idx on public.disputes (request_id);

create trigger disputes_set_updated_at
  before update on public.disputes
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- cancellation_records
-- ---------------------------------------------------------------------------

-- Cancellations are recorded, never expressed by deleting the job. The
-- cancellation rate this feeds is one of the matching inputs, so the history
-- has to be complete.
create table public.cancellation_records (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete restrict,
  cancelled_by uuid references public.profiles (id) on delete set null,
  cancelled_by_role public.service_actor not null,

  reason text not null,
  -- Where the job had got to, so the policy applied can be explained later.
  status_at_cancellation public.service_status not null,
  fee_sen bigint not null default 0,
  fee_waived boolean not null default false,

  created_at timestamptz not null default now(),

  unique (request_id),
  constraint cancellation_fee_non_negative check (fee_sen >= 0),
  constraint cancellation_reason_length
    check (char_length(reason) between 3 and 1000)
);

create index cancellation_records_actor_idx
  on public.cancellation_records (cancelled_by, created_at desc);
