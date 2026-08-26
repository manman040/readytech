-- ReadyTech :: service lifecycle enforcement
--
-- This file is why a client cannot move a job wherever it likes. Every write to
-- service_requests.status passes through service_request_status_guard(), which
-- checks the move against the transition table and the actor's role, and
-- refuses anything else with SQLSTATE RT409.
--
-- The table below is mirrored in app/lib/data/models/service_status.dart. The
-- Dart copy exists so the UI can hide buttons that would be rejected; this copy
-- is the one that decides.

create table public.service_status_transitions (
  from_status public.service_status not null,
  to_status public.service_status not null,
  allowed_actors public.service_actor[] not null,
  primary key (from_status, to_status)
);

comment on table public.service_status_transitions is
  'The state machine, as data. A new transition is a migration, which means it '
  'is reviewed - not a constant someone changed in a hurry.';

insert into public.service_status_transitions (from_status, to_status, allowed_actors) values
  -- Intake and matching. A client cannot assign itself a technician; only the
  -- matching function, running with the service role, may do that.
  ('REQUESTED', 'MATCHING', '{system}'),
  ('REQUESTED', 'ASSIGNED', '{system}'),
  ('REQUESTED', 'CANCELLED', '{customer,admin}'),

  ('MATCHING', 'ASSIGNED', '{system}'),
  ('MATCHING', 'CANCELLED', '{system,customer,admin}'),

  -- Travel.
  ('ASSIGNED', 'TECHNICIAN_ON_THE_WAY', '{technician}'),
  ('ASSIGNED', 'MATCHING', '{system,admin}'),
  ('ASSIGNED', 'CANCELLED', '{technician,customer,admin}'),

  ('TECHNICIAN_ON_THE_WAY', 'ARRIVED', '{technician}'),
  ('TECHNICIAN_ON_THE_WAY', 'MATCHING', '{system,admin}'),
  ('TECHNICIAN_ON_THE_WAY', 'CANCELLED', '{technician,customer,admin}'),

  -- On site. CHECKING_IN is additionally gated on the arrival code below.
  ('ARRIVED', 'CHECKING_IN', '{technician}'),
  ('ARRIVED', 'CANCELLED', '{technician,customer,admin}'),
  ('ARRIVED', 'DISPUTED', '{customer,admin}'),

  ('CHECKING_IN', 'DIAGNOSING', '{technician}'),
  ('CHECKING_IN', 'CANCELLED', '{technician,customer,admin}'),
  ('CHECKING_IN', 'DISPUTED', '{customer,admin}'),

  ('DIAGNOSING', 'QUOTATION_PENDING', '{technician}'),
  ('DIAGNOSING', 'CANCELLED', '{technician,customer,admin}'),
  ('DIAGNOSING', 'DISPUTED', '{customer,admin}'),

  -- Quotation.
  ('QUOTATION_PENDING', 'QUOTATION_SUBMITTED', '{technician}'),
  ('QUOTATION_PENDING', 'CANCELLED', '{technician,customer,admin}'),
  ('QUOTATION_PENDING', 'DISPUTED', '{customer,admin}'),

  ('QUOTATION_SUBMITTED', 'AWAITING_CUSTOMER_APPROVAL', '{system}'),
  ('QUOTATION_SUBMITTED', 'DISPUTED', '{customer,admin}'),

  ('AWAITING_CUSTOMER_APPROVAL', 'APPROVED', '{customer}'),
  ('AWAITING_CUSTOMER_APPROVAL', 'CANCELLED', '{customer,admin}'),
  ('AWAITING_CUSTOMER_APPROVAL', 'DISPUTED', '{customer,admin}'),

  -- Repair. Only the customer may declare the work finished.
  ('APPROVED', 'REPAIRING', '{technician}'),
  ('APPROVED', 'CANCELLED', '{admin}'),
  ('APPROVED', 'DISPUTED', '{customer,admin}'),

  ('REPAIRING', 'WAITING_FOR_PART', '{technician}'),
  ('REPAIRING', 'ADDITIONAL_QUOTE_PENDING', '{technician}'),
  ('REPAIRING', 'COMPLETED', '{customer}'),
  ('REPAIRING', 'CANCELLED', '{admin}'),
  ('REPAIRING', 'DISPUTED', '{customer,admin}'),

  ('WAITING_FOR_PART', 'REPAIRING', '{technician}'),
  ('WAITING_FOR_PART', 'CANCELLED', '{customer,admin}'),
  ('WAITING_FOR_PART', 'DISPUTED', '{customer,admin}'),

  ('ADDITIONAL_QUOTE_PENDING', 'REPAIRING', '{customer}'),
  ('ADDITIONAL_QUOTE_PENDING', 'CANCELLED', '{customer,admin}'),
  ('ADDITIONAL_QUOTE_PENDING', 'DISPUTED', '{customer,admin}'),

  -- Settlement. Only the payment webhook, running as the service role, marks
  -- a job paid.
  ('COMPLETED', 'PAYMENT_PENDING', '{system}'),
  ('COMPLETED', 'DISPUTED', '{customer,admin}'),

  ('PAYMENT_PENDING', 'PAID', '{system}'),
  ('PAYMENT_PENDING', 'DISPUTED', '{customer,admin}'),

  ('PAID', 'WARRANTY_ACTIVE', '{system}'),
  ('PAID', 'DISPUTED', '{customer,admin}'),

  ('WARRANTY_ACTIVE', 'DISPUTED', '{customer,admin}'),

  -- Dispute outcomes, administrator only.
  ('DISPUTED', 'WARRANTY_ACTIVE', '{admin}'),
  ('DISPUTED', 'PAID', '{admin}'),
  ('DISPUTED', 'REPAIRING', '{admin}'),
  ('DISPUTED', 'CANCELLED', '{admin}');

-- ---------------------------------------------------------------------------
-- Trusted internal writes
-- ---------------------------------------------------------------------------

-- Distinguishes "the user is editing this row" from "our own code is
-- maintaining it".
--
-- The column guards further down refuse to let a client change a technician's
-- reputation or a job's assignment. But our own triggers do exactly that: the
-- counter refresh updates technician_profiles, and accept_job_offer() sets
-- assigned_technician_id. Those writes carry the caller's JWT - SECURITY
-- DEFINER changes the role, not auth.uid() - so without this they are
-- indistinguishable from the tampering the guards exist to stop, and the guard
-- rejects the system's own bookkeeping.
--
-- Two signals, both narrow:
--   * pg_trigger_depth() > 1 means we are inside a cascade from another
--     trigger. A client statement always arrives at depth 1.
--   * The readytech.internal_write flag, which a trusted SECURITY DEFINER
--     function raises immediately before its privileged write and lowers
--     immediately after.
--
-- A client cannot raise the flag itself. PostgREST executes no arbitrary SQL
-- and exposes only functions in the public schema, so there is no route to
-- set_config() in pg_catalog; and the flag is set transaction-locally, so it
-- cannot survive into a later request. It is lowered explicitly rather than
-- left to transaction end so that nothing else in the same transaction
-- inherits the exemption.
create or replace function public.is_internal_write()
returns boolean
language sql
stable
as $$
  select pg_trigger_depth() > 1
      or coalesce(
           nullif(current_setting('readytech.internal_write', true), ''),
           'off'
         ) = 'on';
$$;

comment on function public.is_internal_write is
  'True only for writes originating inside our own triggers or inside a '
  'trusted function that has explicitly marked itself. Never true for a '
  'statement sent by a client.';

-- ---------------------------------------------------------------------------
-- Actor resolution
-- ---------------------------------------------------------------------------

-- Which actor is making this change.
--
-- 'system' is returned when there is no authenticated user, which is the case
-- inside an Edge Function using the service role or a webhook. That is the only
-- way to obtain system authority: a signed-in client is always customer,
-- technician or admin, whatever it claims.
create or replace function public.current_service_actor(request public.service_requests)
returns public.service_actor
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  caller uuid := auth.uid();
begin
  -- No JWT means an Edge Function or a webhook under the service role.
  --
  -- A trusted internal write counts as the system too, and it has to: when a
  -- technician calls accept_job_offer(), the job is still unassigned, so the
  -- caller matches neither the customer nor the (null) assigned technician and
  -- would be classified as a stranger. The sanctioned path for MATCHING ->
  -- ASSIGNED is exactly this function, and it is the system that takes it.
  if caller is null or public.is_internal_write() then
    return 'system';
  end if;

  if public.is_admin() then
    return 'admin';
  end if;

  if caller = request.customer_id then
    return 'customer';
  end if;

  if request.assigned_technician_id is not null
     and caller = request.assigned_technician_id then
    return 'technician';
  end if;

  -- Authenticated but unrelated to this job. Deliberately not 'system'.
  return 'customer';
end;
$$;

-- ---------------------------------------------------------------------------
-- The guard
-- ---------------------------------------------------------------------------

create or replace function public.service_request_status_guard()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  actor public.service_actor;
  permitted public.service_actor[];
begin
  if new.status = old.status then
    return new;
  end if;

  actor := public.current_service_actor(old);

  select allowed_actors
    into permitted
    from public.service_status_transitions
   where from_status = old.status
     and to_status = new.status;

  if permitted is null then
    raise exception
      'A job at "%" cannot move to "%".', old.status, new.status
      using errcode = 'RT409';
  end if;

  if not (actor = any(permitted)) then
    raise exception
      'You are not allowed to move this job from "%" to "%".',
      old.status, new.status
      using errcode = 'RT403';
  end if;

  -- Additional guards that the transition table alone cannot express.

  -- Check-in requires the code the customer read out. Without this, a
  -- technician could start billable work having never reached the door.
  if new.status = 'CHECKING_IN'
     and new.arrival_code_verified_at is null then
    raise exception
      'Enter the verification code from the customer before checking in.'
      using errcode = 'RT400';
  end if;

  -- Repair may only start against an approved quotation. This is the rule the
  -- whole quotation flow exists to protect.
  if new.status = 'REPAIRING' and old.status = 'APPROVED' then
    if not exists (
      select 1
        from public.quotations q
       where q.request_id = new.id
         and q.status = 'approved'
    ) then
      raise exception
        'Repair cannot start until the customer approves a quotation.'
        using errcode = 'RT400';
    end if;
  end if;

  -- Resuming after extra work requires that extra work to have been approved
  -- too, not merely proposed.
  if new.status = 'REPAIRING' and old.status = 'ADDITIONAL_QUOTE_PENDING' then
    if not exists (
      select 1
        from public.quotations q
       where q.request_id = new.id
         and q.kind = 'additional'
         and q.status = 'approved'
    ) then
      raise exception
        'The additional work has not been approved yet.'
        using errcode = 'RT400';
    end if;
  end if;

  -- A job cannot be marked paid without a verified payment behind it.
  if new.status = 'PAID' then
    if not exists (
      select 1
        from public.payments p
       where p.request_id = new.id
         and p.status = 'paid'
         and p.verified_at is not null
    ) then
      raise exception 'No verified payment exists for this job.'
        using errcode = 'RT409';
    end if;
  end if;

  -- Assignment must name a technician.
  if new.status = 'ASSIGNED' and new.assigned_technician_id is null then
    raise exception 'A job cannot be assigned without a technician.'
      using errcode = 'RT400';
  end if;

  -- Keep the milestone timestamps truthful; they are read by reporting and by
  -- the cancellation policy.
  new.matched_at := coalesce(new.matched_at,
    case when new.status = 'MATCHING' then now() end);
  new.assigned_at := coalesce(new.assigned_at,
    case when new.status = 'ASSIGNED' then now() end);
  new.arrived_at := coalesce(new.arrived_at,
    case when new.status = 'ARRIVED' then now() end);
  new.diagnosis_at := coalesce(new.diagnosis_at,
    case when new.status = 'DIAGNOSING' then now() end);
  new.approved_at := coalesce(new.approved_at,
    case when new.status = 'APPROVED' then now() end);
  new.completed_at := coalesce(new.completed_at,
    case when new.status = 'COMPLETED' then now() end);
  new.paid_at := coalesce(new.paid_at,
    case when new.status = 'PAID' then now() end);
  new.cancelled_at := coalesce(new.cancelled_at,
    case when new.status = 'CANCELLED' then now() end);

  return new;
end;
$$;

create trigger service_requests_status_guard
  before update of status on public.service_requests
  for each row execute function public.service_request_status_guard();

-- ---------------------------------------------------------------------------
-- History
-- ---------------------------------------------------------------------------

create or replace function public.record_service_status_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.service_status_history
      (request_id, from_status, to_status, actor_id, actor_role)
    values (new.id, null, new.status, auth.uid(),
            public.current_service_actor(new));
    return new;
  end if;

  if new.status is distinct from old.status then
    insert into public.service_status_history
      (request_id, from_status, to_status, actor_id, actor_role)
    values (new.id, old.status, new.status, auth.uid(),
            public.current_service_actor(old));
  end if;

  return new;
end;
$$;

create trigger service_requests_record_history
  after insert or update of status on public.service_requests
  for each row execute function public.record_service_status_change();

-- ---------------------------------------------------------------------------
-- Fields a client may never change
-- ---------------------------------------------------------------------------

-- Row level security decides who may update a row; this decides which columns
-- survive the update. Without it, a customer with update permission on their
-- own request could rewrite the assigned technician or the agreed estimate.
create or replace function public.service_requests_protect_columns()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Edge Functions and webhooks run without a JWT and are trusted, as are our
  -- own triggers and the lifecycle functions that mark themselves.
  if auth.uid() is null or public.is_admin() or public.is_internal_write() then
    return new;
  end if;

  if new.customer_id is distinct from old.customer_id
    or new.reference is distinct from old.reference
    or new.assigned_technician_id is distinct from old.assigned_technician_id
    or new.estimated_total_min_sen is distinct from old.estimated_total_min_sen
    or new.estimated_total_max_sen is distinct from old.estimated_total_max_sen
    or new.arrival_code is distinct from old.arrival_code
    or new.requested_at is distinct from old.requested_at
  then
    raise exception 'That field cannot be changed.'
      using errcode = 'RT403';
  end if;

  return new;
end;
$$;

create trigger service_requests_protect
  before update on public.service_requests
  for each row execute function public.service_requests_protect_columns();

-- ---------------------------------------------------------------------------
-- Arrival verification
-- ---------------------------------------------------------------------------

-- Verifying the code is a function, not an update, so the code itself never has
-- to be readable by the technician's client. They submit a guess; the database
-- compares it.
create or replace function public.verify_arrival_code(
  request_id uuid,
  submitted_code text
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  target public.service_requests;
begin
  select * into target
    from public.service_requests
   where id = request_id
   for update;

  if not found then
    raise exception 'That job no longer exists.' using errcode = 'RT404';
  end if;

  if auth.uid() is distinct from target.assigned_technician_id then
    raise exception 'Only the assigned technician can check in.'
      using errcode = 'RT403';
  end if;

  if target.status <> 'ARRIVED' then
    raise exception 'Mark yourself as arrived before entering the code.'
      using errcode = 'RT409';
  end if;

  if target.arrival_code is distinct from submitted_code then
    raise exception 'That code does not match. Ask the customer to read it again.'
      using errcode = 'RT400';
  end if;

  update public.service_requests
     set arrival_code_verified_at = now(),
         status = 'CHECKING_IN'
   where id = request_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Active job lookup
-- ---------------------------------------------------------------------------

-- Backs "resume the active booking" on cold start. Returning the id only keeps
-- the splash path cheap; the screen then loads the row through the normal
-- policies.
create or replace function public.active_service_request()
returns uuid
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select r.id
    from public.service_requests r
   where (
           r.customer_id = auth.uid()
           or r.assigned_technician_id = auth.uid()
         )
     and r.status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED')
   order by r.created_at desc
   limit 1;
$$;

-- ---------------------------------------------------------------------------
-- Technician counters
-- ---------------------------------------------------------------------------

create or replace function public.refresh_technician_job_counters()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target uuid := coalesce(new.assigned_technician_id, old.assigned_technician_id);
begin
  if target is null then
    return null;
  end if;

  update public.technician_profiles t
     set completed_jobs = stats.completed,
         cancelled_jobs = stats.cancelled
    from (
      select
        count(*) filter (
          where status in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE')
        ) as completed,
        count(*) filter (where status = 'CANCELLED') as cancelled
      from public.service_requests
      where assigned_technician_id = target
    ) as stats
   where t.id = target;

  return null;
end;
$$;

create trigger service_requests_refresh_counters
  after update of status on public.service_requests
  for each row execute function public.refresh_technician_job_counters();

create or replace function public.refresh_technician_offer_counters()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target uuid := coalesce(new.technician_id, old.technician_id);
begin
  update public.technician_profiles t
     set offers_received = stats.received,
         offers_accepted = stats.accepted
    from (
      select count(*) as received,
             count(*) filter (where status = 'accepted') as accepted
        from public.technician_assignments
       where technician_id = target
    ) as stats
   where t.id = target;

  return null;
end;
$$;

create trigger technician_assignments_refresh_counters
  after insert or update of status or delete on public.technician_assignments
  for each row execute function public.refresh_technician_offer_counters();
