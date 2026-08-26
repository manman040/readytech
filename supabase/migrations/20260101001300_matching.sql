-- ReadyTech :: technician matching
--
-- Matching runs in the database, not in the app. Two reasons: the ranking
-- inputs (rating, cancellation rate, workload, live distance) are things a
-- client must not be able to see or influence, and acceptance has to be
-- serialised against a lock or two technicians will accept the same job.

-- ---------------------------------------------------------------------------
-- Ranking
-- ---------------------------------------------------------------------------

create or replace function public.rank_technicians(
  request_id uuid,
  radius_km numeric default null,
  max_results integer default 10
)
returns table (
  technician_id uuid,
  full_name text,
  avatar_url text,
  rating_average numeric,
  rating_count integer,
  completed_jobs integer,
  distance_km numeric,
  eta_minutes integer,
  specialisation smallint,
  score numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  target public.service_requests;
  weights jsonb;
  search_radius numeric;
begin
  select * into target from public.service_requests r where r.id = request_id;
  if not found then
    raise exception 'That job no longer exists.' using errcode = 'RT404';
  end if;

  -- Only the customer on the job, or an administrator, may ask who matches it.
  if not (public.is_request_customer(request_id) or public.is_admin()
          or auth.uid() is null) then
    raise exception 'You cannot view matches for this job.'
      using errcode = 'RT403';
  end if;

  weights := (select value from public.pricing_config where key = 'matching_weights');
  search_radius := coalesce(
    radius_km,
    public.pricing_numeric('matching_radius_km'),
    15
  );

  return query
  with candidates as (
    select
      t.id,
      p.full_name,
      p.avatar_url,
      t.rating_average,
      t.rating_count,
      t.completed_jobs,
      t.cancelled_jobs,
      t.offers_received,
      t.offers_accepted,
      t.accepts_emergency,
      -- Live position when we have one, otherwise where they are based.
      round(
        (extensions.st_distance(
          coalesce(loc.location, t.base_location),
          target.service_location
        ) / 1000)::numeric,
        2
      ) as distance_km,
      coalesce(skill.proficiency, 0::smallint) as specialisation,
      -- Jobs currently in flight. A technician mid-repair is a poor match even
      -- if they are the closest.
      (
        select count(*)
        from public.service_requests active
        where active.assigned_technician_id = t.id
          and active.status not in
              ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED')
      ) as active_jobs
    from public.technician_profiles t
    join public.profiles p on p.id = t.id
    left join public.technician_locations loc on loc.technician_id = t.id
    left join public.technician_skills skill
      on skill.technician_id = t.id
     and skill.category_id = target.category_id
    where t.is_available
      and t.verification_status = 'approved'
      -- Emergencies only go to technicians who opted in to them.
      and (target.urgency <> 'emergency' or t.accepts_emergency)
      -- Inside our search radius and inside the radius they agreed to travel.
      and extensions.st_dwithin(
        coalesce(loc.location, t.base_location),
        target.service_location,
        least(search_radius, t.service_radius_km) * 1000
      )
      -- Never re-offer a job that this technician already turned down.
      and not exists (
        select 1 from public.technician_assignments a
        where a.request_id = target.id
          and a.technician_id = t.id
          and a.status in ('declined', 'expired')
      )
  )
  select
    c.id,
    c.full_name,
    c.avatar_url,
    c.rating_average,
    c.rating_count,
    c.completed_jobs,
    c.distance_km,
    -- 25 km/h average through city traffic, plus five minutes to park and
    -- reach the door. A straight-line ETA that ignores both reads as
    -- optimistic every single time.
    (ceil((c.distance_km / 25.0) * 60) + 5)::integer as eta_minutes,
    c.specialisation,
    round(
      -- Specialisation: proficiency 1-5 scaled to the weight.
      (coalesce((weights ->> 'specialisation')::numeric, 40)
        * (c.specialisation / 5.0))
      -- Distance: full marks at the door, zero at the edge of the radius.
      + (coalesce((weights ->> 'distance')::numeric, 20)
        * greatest(0, 1 - (c.distance_km / nullif(search_radius, 0))))
      -- Availability: penalised for each job already in hand.
      + (coalesce((weights ->> 'availability')::numeric, 15)
        * greatest(0, 1 - (c.active_jobs / 2.0)))
      -- Rating: a technician with no reviews is treated as average rather
      -- than as bad, so a new joiner is not frozen out permanently.
      + (coalesce((weights ->> 'rating')::numeric, 10)
        * (case when c.rating_count = 0 then 0.7
                else c.rating_average / 5.0 end))
      -- Response rate.
      + (coalesce((weights ->> 'response_rate')::numeric, 5)
        * (case when c.offers_received = 0 then 0.7
                else c.offers_accepted::numeric / c.offers_received end))
      -- Completion rate.
      + (coalesce((weights ->> 'completion_rate')::numeric, 5)
        * (case when (c.completed_jobs + c.cancelled_jobs) = 0 then 0.7
                else c.completed_jobs::numeric
                     / (c.completed_jobs + c.cancelled_jobs) end))
      -- ETA: full marks under fifteen minutes, tapering to nothing at an hour.
      + (coalesce((weights ->> 'eta')::numeric, 5)
        * greatest(0, 1 - (((c.distance_km / 25.0) * 60) / 60.0)))
      , 2
    ) as score
  from candidates c
  order by score desc, c.distance_km asc
  limit max_results;
end;
$$;

comment on function public.rank_technicians is
  'Returns candidates in rank order. The score column is for the matching '
  'function and the admin console; it is never rendered in the customer app.';

-- ---------------------------------------------------------------------------
-- Offers
-- ---------------------------------------------------------------------------

-- What a technician sees before they accept.
--
-- Deliberately redacted: no street address, no customer name, no phone number.
-- A technician gets those by accepting the job and turning up, which is a
-- commitment. Without this function they would need select on service_requests,
-- and every offer would hand out a stranger's home address.
create or replace function public.technician_open_offers()
returns table (
  assignment_id uuid,
  request_id uuid,
  reference text,
  category_name text,
  problem_summary text,
  urgency public.urgency_level,
  distance_km numeric,
  eta_minutes integer,
  estimated_total_min_sen bigint,
  estimated_total_max_sen bigint,
  -- Enough to navigate towards, not enough to identify a household.
  approximate_latitude numeric,
  approximate_longitude numeric,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select
    a.id,
    r.id,
    r.reference,
    coalesce(c.name, 'General IT support'),
    coalesce(r.problem_summary, left(r.problem_description, 140)),
    r.urgency,
    a.distance_km,
    a.eta_minutes,
    r.estimated_total_min_sen,
    r.estimated_total_max_sen,
    -- Rounded to roughly a hundred metres.
    round(r.service_latitude, 3),
    round(r.service_longitude, 3),
    a.expires_at
  from public.technician_assignments a
  join public.service_requests r on r.id = a.request_id
  left join public.service_categories c on c.id = r.category_id
  where a.technician_id = auth.uid()
    and a.status = 'offered'
    and a.expires_at > now()
    and r.status in ('REQUESTED', 'MATCHING')
  order by a.rank asc, a.offered_at asc;
$$;

-- ---------------------------------------------------------------------------
-- Acceptance
-- ---------------------------------------------------------------------------

-- The one way a technician takes a job.
--
-- The row lock is the whole point. Two technicians tapping Accept at the same
-- instant both reach this function; the first takes the lock, sets the status
-- away from MATCHING, and the second finds a job that is no longer available.
-- The partial unique indexes on service_requests and technician_assignments are
-- the backstop if this is ever bypassed.
create or replace function public.accept_job_offer(request_id uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  caller uuid := auth.uid();
  target public.service_requests;
  offer public.technician_assignments;
begin
  if caller is null then
    raise exception 'You must be signed in.' using errcode = 'RT403';
  end if;

  if not public.technician_is_matchable(caller) then
    raise exception
      'Your account must be verified and online before you can accept jobs.'
      using errcode = 'RT403';
  end if;

  -- Serialise every acceptance for this job behind one lock.
  select * into target
    from public.service_requests r
   where r.id = accept_job_offer.request_id
   for update;

  if not found then
    raise exception 'That job no longer exists.' using errcode = 'RT404';
  end if;

  if target.status not in ('REQUESTED', 'MATCHING') then
    raise exception 'This job has already been taken.' using errcode = 'RT409';
  end if;

  select * into offer
    from public.technician_assignments a
   where a.request_id = accept_job_offer.request_id
     and a.technician_id = caller
   for update;

  if not found then
    raise exception 'This job was not offered to you.' using errcode = 'RT403';
  end if;

  if offer.status <> 'offered' then
    raise exception 'You have already responded to this job.'
      using errcode = 'RT409';
  end if;

  if offer.expires_at <= now() then
    update public.technician_assignments
       set status = 'expired', responded_at = now()
     where id = offer.id;
    raise exception 'This offer has expired.' using errcode = 'RT409';
  end if;

  -- A technician can only hold one live job at a time.
  if exists (
    select 1 from public.service_requests other
    where other.assigned_technician_id = caller
      and other.status not in
          ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED')
  ) then
    raise exception 'Finish your current job before accepting another.'
      using errcode = 'RT409';
  end if;

  update public.technician_assignments
     set status = 'accepted', responded_at = now()
   where id = offer.id;

  -- Everyone else's offer closes the moment this one is taken.
  update public.technician_assignments
     set status = 'withdrawn', responded_at = now()
   where technician_assignments.request_id = accept_job_offer.request_id
     and id <> offer.id
     and status = 'offered';

  -- Assigning a technician is exactly what the column guard forbids a client
  -- from doing. This is the one sanctioned path, so it marks itself as a
  -- trusted internal write - and lowers the flag immediately afterwards, so
  -- nothing else in the transaction inherits the exemption.
  perform set_config('readytech.internal_write', 'on', true);

  update public.service_requests
     set assigned_technician_id = caller,
         status = 'ASSIGNED',
         assigned_at = now(),
         estimated_distance_km = coalesce(offer.distance_km, estimated_distance_km),
         estimated_eta_minutes = coalesce(offer.eta_minutes, estimated_eta_minutes)
   where id = accept_job_offer.request_id;

  perform set_config('readytech.internal_write', 'off', true);

  return accept_job_offer.request_id;
end;
$$;

create or replace function public.decline_job_offer(
  request_id uuid,
  reason text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
begin
  update public.technician_assignments
     set status = 'declined',
         responded_at = now(),
         decline_reason = reason
   where technician_assignments.request_id = decline_job_offer.request_id
     and technician_id = auth.uid()
     and status = 'offered';

  if not found then
    raise exception 'There is no open offer for you on this job.'
      using errcode = 'RT404';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Estimates
-- ---------------------------------------------------------------------------

-- Builds the pre-diagnosis range shown before a customer commits.
--
-- Returns a range rather than a figure, and the range comes from the category
-- and the pricing table rather than from anything the client sent. A client
-- that could name its own estimate could show a customer a number the
-- technician never agreed to.
create or replace function public.estimate_service_cost(
  category_id uuid,
  urgency public.urgency_level,
  distance_km numeric
)
returns table (
  diagnosis_fee_sen bigint,
  travel_fee_sen bigint,
  urgency_fee_sen bigint,
  platform_fee_sen bigint,
  repair_min_sen bigint,
  repair_max_sen bigint,
  total_min_sen bigint,
  total_max_sen bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  category public.service_categories;
  diagnosis bigint;
  travel bigint;
  urgency_fee bigint;
  platform bigint;
begin
  select * into category
    from public.service_categories c
   where c.id = estimate_service_cost.category_id;

  diagnosis := coalesce(
    category.diagnosis_fee_sen,
    public.pricing_int('diagnosis_fee_sen'),
    2000
  );

  travel := least(
    coalesce(public.pricing_int('travel_base_fee_sen'), 500)
      + round(
          coalesce(distance_km, 0)
          * coalesce(public.pricing_int('travel_per_km_sen'), 100)
        )::bigint,
    coalesce(public.pricing_int('travel_fee_cap_sen'), 3000)
  );

  urgency_fee := case urgency
    when 'emergency' then coalesce(public.pricing_int('emergency_surcharge_sen'), 3000)
    when 'priority' then coalesce(public.pricing_int('priority_surcharge_sen'), 1000)
    else 0
  end;

  platform := coalesce(public.pricing_int('platform_fee_sen'), 500);

  return query select
    diagnosis,
    travel,
    urgency_fee,
    platform,
    coalesce(category.estimated_repair_min_sen, 0),
    coalesce(category.estimated_repair_max_sen, 0),
    diagnosis + travel + urgency_fee + platform
      + coalesce(category.estimated_repair_min_sen, 0),
    diagnosis + travel + urgency_fee + platform
      + coalesce(category.estimated_repair_max_sen, 0);
end;
$$;
