-- ReadyTech :: technicians
--
-- A technician profile extends a normal profile rather than replacing it. The
-- counters near the bottom of technician_profiles are denormalised on purpose:
-- matching has to rank candidates on every request, and recomputing an average
-- rating and a completion rate from the history tables each time would put a
-- join over the whole service_requests table in the hot path.

create table public.technician_profiles (
  id uuid primary key references public.profiles (id) on delete cascade,

  headline text not null default '',
  bio text not null default '',
  years_experience integer not null default 0,

  -- Where the technician starts their day. Live position lives in
  -- technician_locations and is only shared during an active job.
  base_latitude numeric(9, 6),
  base_longitude numeric(9, 6),
  base_location extensions.geography(Point, 4326)
    generated always as (
      case
        when base_latitude is null or base_longitude is null then null
        else extensions.st_setsrid(
          extensions.st_makepoint(base_longitude::float8, base_latitude::float8),
          4326
        )::extensions.geography
      end
    ) stored,
  service_radius_km integer not null default 15,

  -- Set by the technician, but only honoured while verification is approved.
  is_available boolean not null default false,
  accepts_emergency boolean not null default false,

  verification_status public.verification_status not null default 'unsubmitted',
  verified_at timestamptz,
  suspended_reason text,

  -- Reputation, maintained by triggers. Never written by a client.
  rating_average numeric(3, 2) not null default 0,
  rating_count integer not null default 0,
  completed_jobs integer not null default 0,
  cancelled_jobs integer not null default 0,
  offers_received integer not null default 0,
  offers_accepted integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint technician_radius_sane
    check (service_radius_km between 1 and 100),
  constraint technician_experience_sane
    check (years_experience between 0 and 60),
  constraint technician_rating_range
    check (rating_average >= 0 and rating_average <= 5),
  constraint technician_counters_non_negative
    check (
      rating_count >= 0
      and completed_jobs >= 0
      and cancelled_jobs >= 0
      and offers_received >= 0
      and offers_accepted >= 0
    ),
  constraint technician_base_coordinates_paired
    check (num_nulls(base_latitude, base_longitude) <> 1),
  constraint technician_latitude_range
    check (base_latitude is null or base_latitude between -90 and 90),
  constraint technician_longitude_range
    check (base_longitude is null or base_longitude between -180 and 180)
);

comment on column public.technician_profiles.is_available is
  'The technician''s own switch. Eligibility for matching also requires an '
  'approved verification - see technician_is_matchable().';

create index technician_profiles_base_location_idx
  on public.technician_profiles using gist (base_location);

-- The matching query filters on exactly this combination.
create index technician_profiles_matchable_idx
  on public.technician_profiles (is_available, verification_status)
  where is_available and verification_status = 'approved';

create trigger technician_profiles_set_updated_at
  before update on public.technician_profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- technician_skills
-- ---------------------------------------------------------------------------

create table public.technician_skills (
  id uuid primary key default extensions.gen_random_uuid(),
  technician_id uuid not null
    references public.technician_profiles (id) on delete cascade,
  category_id uuid not null
    references public.service_categories (id) on delete cascade,
  -- 1 = capable, 5 = specialist. Feeds the specialisation weight in matching.
  proficiency smallint not null default 3,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),

  constraint technician_skills_proficiency_range
    check (proficiency between 1 and 5),
  unique (technician_id, category_id)
);

create index technician_skills_category_idx
  on public.technician_skills (category_id, proficiency desc);

-- ---------------------------------------------------------------------------
-- technician_verifications
-- ---------------------------------------------------------------------------

create table public.technician_verifications (
  id uuid primary key default extensions.gen_random_uuid(),
  technician_id uuid not null
    references public.technician_profiles (id) on delete cascade,
  document_type text not null,
  -- Object key in the private technician-documents bucket, not a public URL.
  storage_path text not null,
  status public.verification_status not null default 'pending',
  reviewed_by uuid references public.profiles (id) on delete set null,
  reviewed_at timestamptz,
  reviewer_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint technician_verifications_reviewed_together
    check (
      (status in ('pending', 'unsubmitted'))
      or (reviewed_by is not null and reviewed_at is not null)
    )
);

create index technician_verifications_queue_idx
  on public.technician_verifications (status, created_at)
  where status = 'pending';

create index technician_verifications_technician_idx
  on public.technician_verifications (technician_id, created_at desc);

create trigger technician_verifications_set_updated_at
  before update on public.technician_verifications
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- technician_locations
-- ---------------------------------------------------------------------------

-- One row per technician holding the current position, not a track. Retaining
-- an unbounded history of where a person has been is a liability with no
-- product use: tracking only needs "where are they now".
create table public.technician_locations (
  technician_id uuid primary key
    references public.technician_profiles (id) on delete cascade,
  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  location extensions.geography(Point, 4326)
    generated always as (
      extensions.st_setsrid(
        extensions.st_makepoint(longitude::float8, latitude::float8),
        4326
      )::extensions.geography
    ) stored,
  heading numeric(5, 2),
  accuracy_metres numeric(7, 2),
  updated_at timestamptz not null default now(),

  constraint technician_locations_latitude_range
    check (latitude between -90 and 90),
  constraint technician_locations_longitude_range
    check (longitude between -180 and 180),
  constraint technician_locations_heading_range
    check (heading is null or heading between 0 and 360)
);

create index technician_locations_location_idx
  on public.technician_locations using gist (location);

-- ---------------------------------------------------------------------------
-- Eligibility
-- ---------------------------------------------------------------------------

create or replace function public.technician_is_matchable(technician uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.technician_profiles t
    where t.id = technician
      and t.is_available
      and t.verification_status = 'approved'
  );
$$;

comment on function public.technician_is_matchable is
  'Availability alone is not enough - an unverified or suspended technician is '
  'never offered work, whatever their own switch says.';
