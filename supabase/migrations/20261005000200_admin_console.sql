-- ReadyTech :: administrator console
--
-- The admin console (admin/) signs in as an ordinary Supabase user whose role
-- happens to be 'admin'. It holds no service-role key. Everything it reads is
-- reached through the is_admin() policies that already exist, and everything it
-- changes goes through the functions in this file.
--
-- Why functions rather than letting the console write tables directly, when
-- the admin policies would allow most of those writes:
--
--   * Atomicity. Approving a technician touches the document, the technician
--     profile and the technician's notification centre. Suspending one also
--     switches off their availability. Cancelling a job writes the status and
--     the cancellation record. A browser issuing those as separate requests
--     can stop halfway; a function cannot.
--   * Notifications. No client may insert a notification - that rule exists so
--     nobody can put arbitrary text in someone else's notification centre - so
--     the console could not tell a technician they were approved even if it
--     wanted to.
--   * Accountability. Administrators are the one role that can override
--     almost everything, which is exactly why what they do has to be written
--     down somewhere they cannot edit. Every function here appends to
--     admin_audit_log.
--
-- Money is still not the console's to move. Payments and technician earnings
-- stay read-only to every signed-in user, administrators included; settling,
-- refunding and releasing are the payment Edge Functions' job, under the
-- service role, after they have spoken to the provider.

-- ---------------------------------------------------------------------------
-- admin_audit_log
-- ---------------------------------------------------------------------------

create table public.admin_audit_log (
  id uuid primary key default extensions.gen_random_uuid(),
  admin_id uuid references public.profiles (id) on delete set null,
  -- A short verb phrase such as 'technician.suspend'. Text rather than an
  -- enum: the log must never refuse a write because a new action was added
  -- without a migration to the type.
  action text not null,
  target_table text not null,
  target_id text not null,
  -- Before and after values, the reason given, anything needed to explain the
  -- action later without reconstructing it from other tables.
  detail jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),

  constraint admin_audit_log_action_length
    check (char_length(action) between 3 and 80)
);

comment on table public.admin_audit_log is
  'Append-only record of administrative actions. Written only by the admin_* '
  'functions; nobody, administrators included, can update or delete a row.';

create index admin_audit_log_created_idx
  on public.admin_audit_log (created_at desc);

create index admin_audit_log_target_idx
  on public.admin_audit_log (target_table, target_id, created_at desc);

alter table public.admin_audit_log enable row level security;

create policy admin_audit_log_select_admin
  on public.admin_audit_log for select to authenticated
  using (public.is_admin());

-- No write policy and, below, no write privilege. The functions that append to
-- it are SECURITY DEFINER.

-- ---------------------------------------------------------------------------
-- Message moderation
-- ---------------------------------------------------------------------------

-- A report used to be a one-way flag: reported_at was set and nothing could
-- say it had been looked at, so the moderation queue could only grow. These
-- record the review without erasing the fact that the report was made.
alter table public.messages
  add column report_reviewed_at timestamptz,
  add column report_reviewed_by uuid references public.profiles (id) on delete set null;

create index messages_report_queue_idx
  on public.messages (reported_at)
  where reported_at is not null and report_reviewed_at is null;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function public.require_admin()
returns void
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
begin
  if not public.is_admin() then
    raise exception 'Only an administrator can do that.' using errcode = 'RT403';
  end if;
end;
$$;

create or replace function public.admin_log(
  action text,
  target_table text,
  target_id text,
  detail jsonb default '{}'::jsonb
)
returns void
language sql
volatile
security definer
set search_path = public, pg_temp
as $$
  insert into public.admin_audit_log (admin_id, action, target_table, target_id, detail)
  values (auth.uid(), action, target_table, target_id, coalesce(detail, '{}'::jsonb));
$$;

-- Notifications are otherwise written by the send-notification Edge Function.
-- This is the same write, for the cases where the sender is an administrator.
create or replace function public.admin_notify(
  recipient uuid,
  kind public.notification_type,
  title text,
  body text,
  payload jsonb default '{}'::jsonb
)
returns void
language sql
volatile
security definer
set search_path = public, pg_temp
as $$
  insert into public.notifications (user_id, type, title, body, data)
  values (recipient, kind, left(title, 120), left(body, 500), coalesce(payload, '{}'::jsonb));
$$;

create or replace function public.admin_require_reason(reason text, minimum integer default 3)
returns text
language plpgsql
immutable
as $$
begin
  if reason is null or char_length(btrim(reason)) < minimum then
    raise exception 'Give a reason of at least % characters. It is recorded and may be shown to the people affected.', minimum
      using errcode = 'RT400';
  end if;
  return btrim(reason);
end;
$$;

-- ---------------------------------------------------------------------------
-- Dashboard
-- ---------------------------------------------------------------------------

-- One round trip for the landing page, and the only way to get sums: PostgREST
-- aggregates are off, and fetching every payment to add them up in a browser
-- would be both slow and a needless copy of financial data.
create or replace function public.admin_dashboard_stats()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $$
declare
  result jsonb;
begin
  perform public.require_admin();

  select jsonb_build_object(
    'customers', (select count(*) from public.user_roles where role = 'customer'),
    'technicians', (select count(*) from public.user_roles where role = 'technician'),
    'technicians_approved',
      (select count(*) from public.technician_profiles where verification_status = 'approved'),
    'technicians_available',
      (select count(*) from public.technician_profiles
        where verification_status = 'approved' and is_available),
    'technicians_awaiting_review',
      (select count(distinct v.technician_id) from public.technician_verifications v
        where v.status = 'pending'),
    'documents_pending',
      (select count(*) from public.technician_verifications where status = 'pending'),
    'jobs_active',
      (select count(*) from public.service_requests
        where status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED')),
    'jobs_matching',
      (select count(*) from public.service_requests where status in ('REQUESTED', 'MATCHING')),
    'jobs_awaiting_approval',
      (select count(*) from public.service_requests
        where status in ('AWAITING_CUSTOMER_APPROVAL', 'ADDITIONAL_QUOTE_PENDING')),
    'jobs_payment_pending',
      (select count(*) from public.service_requests where status = 'PAYMENT_PENDING'),
    'jobs_completed_30d',
      (select count(*) from public.service_requests
        where completed_at > now() - interval '30 days'),
    'jobs_cancelled_30d',
      (select count(*) from public.service_requests
        where cancelled_at > now() - interval '30 days'),
    'jobs_total', (select count(*) from public.service_requests),
    'disputes_open',
      (select count(*) from public.disputes where status in ('open', 'under_review')),
    'messages_reported',
      (select count(*) from public.messages
        where reported_at is not null and report_reviewed_at is null),
    'gross_paid_sen_30d',
      (select coalesce(sum(amount_sen), 0) from public.payments
        where status = 'paid' and paid_at > now() - interval '30 days'),
    'gross_paid_sen_total',
      (select coalesce(sum(amount_sen), 0) from public.payments where status = 'paid'),
    'commission_sen_total',
      (select coalesce(sum(commission_sen), 0) from public.technician_earnings),
    'earnings_pending_sen',
      (select coalesce(sum(net_sen), 0) from public.technician_earnings where status = 'pending'),
    'average_rating',
      (select coalesce(round(avg(rating_overall)::numeric, 2), 0) from public.reviews),
    'jobs_by_status',
      (select coalesce(jsonb_object_agg(status, total), '{}'::jsonb)
         from (select status, count(*) as total
                 from public.service_requests group by status) s)
  ) into result;

  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Technician verification
-- ---------------------------------------------------------------------------

-- Reviews one submitted document. Approving a document of a technician who has
-- not yet been approved approves the technician, which is the moment they
-- become matchable; rejecting one marks a not-yet-approved technician
-- rejected. A technician who is already approved, or suspended, keeps their
-- status - one document does not undo a decision made on the whole person, and
-- suspension is changed only by admin_set_technician_status().
create or replace function public.admin_review_verification(
  verification_id uuid,
  decision public.verification_status,
  notes text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  doc public.technician_verifications;
  tech public.technician_profiles;
  new_status public.verification_status;
begin
  perform public.require_admin();

  if decision not in ('approved', 'rejected') then
    raise exception 'A document can only be approved or rejected.' using errcode = 'RT400';
  end if;

  if decision = 'rejected' then
    notes := public.admin_require_reason(notes, 5);
  end if;

  select * into doc from public.technician_verifications
   where id = verification_id
   for update;
  if not found then
    raise exception 'That document no longer exists.' using errcode = 'RT404';
  end if;

  if doc.status <> 'pending' then
    raise exception 'That document has already been reviewed.' using errcode = 'RT409';
  end if;

  update public.technician_verifications
     set status = decision,
         reviewed_by = auth.uid(),
         reviewed_at = now(),
         reviewer_notes = nullif(btrim(coalesce(notes, '')), '')
   where id = verification_id;

  select * into tech from public.technician_profiles
   where id = doc.technician_id
   for update;

  new_status := tech.verification_status;
  if tech.verification_status in ('unsubmitted', 'pending', 'rejected') then
    new_status := decision;
  end if;

  if new_status is distinct from tech.verification_status then
    update public.technician_profiles
       set verification_status = new_status,
           verified_at = case when new_status = 'approved' then now() else verified_at end
     where id = tech.id;
  end if;

  perform public.admin_notify(
    doc.technician_id,
    'verification_updated',
    case decision
      when 'approved' then 'Document approved'
      else 'Document not accepted'
    end,
    case
      when new_status = 'approved' and tech.verification_status <> 'approved'
        then 'You are verified. Switch on availability to start receiving jobs.'
      when decision = 'approved'
        then 'Your ' || replace(doc.document_type, '_', ' ') || ' was accepted.'
      else 'Your ' || replace(doc.document_type, '_', ' ') || ' was not accepted: ' || notes
    end,
    jsonb_build_object('verification_id', doc.id)
  );

  perform public.admin_log(
    'verification.' || decision::text,
    'technician_verifications',
    doc.id::text,
    jsonb_build_object(
      'technician_id', doc.technician_id,
      'document_type', doc.document_type,
      'notes', notes,
      'technician_status_before', tech.verification_status,
      'technician_status_after', new_status
    )
  );
end;
$$;

-- Decides on the technician as a whole: approve, reject, suspend, reinstate.
create or replace function public.admin_set_technician_status(
  technician_id uuid,
  new_status public.verification_status,
  reason text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  tech public.technician_profiles;
begin
  perform public.require_admin();

  if new_status not in ('approved', 'rejected', 'suspended') then
    raise exception 'A technician can be approved, rejected or suspended.'
      using errcode = 'RT400';
  end if;

  if new_status in ('rejected', 'suspended') then
    reason := public.admin_require_reason(reason, 5);
  end if;

  select * into tech from public.technician_profiles t
   where t.id = admin_set_technician_status.technician_id
   for update;
  if not found then
    raise exception 'That technician no longer exists.' using errcode = 'RT404';
  end if;

  if tech.verification_status = new_status then
    raise exception 'That technician is already %.', new_status using errcode = 'RT409';
  end if;

  update public.technician_profiles t
     set verification_status = new_status,
         verified_at = case when new_status = 'approved' then coalesce(t.verified_at, now())
                            else t.verified_at end,
         suspended_reason = case when new_status = 'suspended' then reason else null end,
         -- Availability is the technician's switch, but a suspended or
         -- rejected technician switching it back on would be misleading even
         -- though matching already ignores them. Turned off here; they turn it
         -- on again themselves once reinstated.
         is_available = case when new_status = 'approved' then t.is_available else false end
   where t.id = tech.id;

  perform public.admin_notify(
    tech.id,
    'verification_updated',
    case new_status
      when 'approved' then
        case when tech.verification_status = 'suspended' then 'Account reinstated'
             else 'You are verified' end
      when 'suspended' then 'Account suspended'
      else 'Verification not approved'
    end,
    case new_status
      when 'approved' then
        case when tech.verification_status = 'suspended'
             then 'You can receive jobs again once you switch on availability.'
             else 'Switch on availability to start receiving jobs.' end
      when 'suspended' then 'You will not receive new jobs. Reason: ' || reason
      else 'Your verification was not approved. Reason: ' || reason
    end,
    '{}'::jsonb
  );

  perform public.admin_log(
    'technician.' || new_status::text,
    'technician_profiles',
    tech.id::text,
    jsonb_build_object('from', tech.verification_status, 'to', new_status, 'reason', reason)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Service requests
-- ---------------------------------------------------------------------------

-- An administrator moving a job. The transition table still decides what is
-- legal: this function adds what an admin move needs around it and then lets
-- service_request_status_guard() rule on the status change as usual, with the
-- caller recognised as 'admin'.
create or replace function public.admin_transition_service_request(
  request_id uuid,
  to_status public.service_status,
  reason text
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
  perform public.require_admin();
  reason := public.admin_require_reason(reason, 5);

  select * into target from public.service_requests r
   where r.id = admin_transition_service_request.request_id
   for update;
  if not found then
    raise exception 'That job no longer exists.' using errcode = 'RT404';
  end if;

  if not exists (
    select 1 from public.service_status_transitions t
     where t.from_status = target.status
       and t.to_status = admin_transition_service_request.to_status
       and 'admin' = any(t.allowed_actors)
  ) then
    raise exception 'An administrator cannot move a job from "%" to "%".',
      target.status, to_status using errcode = 'RT409';
  end if;

  if to_status = 'MATCHING' then
    -- Back to matching means the technician no longer holds the job. Without
    -- releasing them, the one-live-job index would keep them bound to a job
    -- they have been taken off.
    update public.technician_assignments a
       set status = 'withdrawn',
           responded_at = coalesce(a.responded_at, now()),
           decline_reason = coalesce(a.decline_reason, 'Withdrawn by an administrator: ' || reason)
     where a.request_id = target.id
       and a.status in ('accepted', 'offered');

    update public.service_requests r
       set status = 'MATCHING',
           assigned_technician_id = null,
           assigned_at = null,
           estimated_eta_minutes = null
     where r.id = target.id;
  else
    update public.service_requests r
       set status = admin_transition_service_request.to_status
     where r.id = target.id;
  end if;

  -- The history row was written by the trigger a moment ago; give it the
  -- reason, so the timeline both participants see explains the change.
  update public.service_status_history h
     set reason = admin_transition_service_request.reason
   where h.id = (
     select h2.id from public.service_status_history h2
      where h2.request_id = target.id
        and h2.to_status = admin_transition_service_request.to_status
      order by h2.created_at desc
      limit 1
   );

  if to_status = 'CANCELLED' then
    -- An administrator cancelling is never the customer's fault, so no fee.
    insert into public.cancellation_records
      (request_id, cancelled_by, cancelled_by_role, reason,
       status_at_cancellation, fee_sen, fee_waived)
    values
      (target.id, auth.uid(), 'admin', reason, target.status, 0, true)
    -- Named rather than "(request_id)", which plpgsql would read as this
    -- function's parameter of the same name.
    on conflict on constraint cancellation_records_request_id_key do nothing;

    perform public.admin_notify(
      target.customer_id, 'job_cancelled', 'Job ' || target.reference || ' cancelled',
      'ReadyTech support cancelled this job. ' || reason,
      jsonb_build_object('request_id', target.id));

    if target.assigned_technician_id is not null then
      perform public.admin_notify(
        target.assigned_technician_id, 'job_cancelled',
        'Job ' || target.reference || ' cancelled',
        'ReadyTech support cancelled this job. ' || reason,
        jsonb_build_object('request_id', target.id));
    end if;
  elsif to_status = 'MATCHING' and target.assigned_technician_id is not null then
    perform public.admin_notify(
      target.assigned_technician_id, 'job_cancelled',
      'Removed from job ' || target.reference,
      'ReadyTech support reassigned this job. ' || reason,
      jsonb_build_object('request_id', target.id));
  end if;

  perform public.admin_log(
    'job.transition',
    'service_requests',
    target.id::text,
    jsonb_build_object(
      'reference', target.reference,
      'from', target.status,
      'to', to_status,
      'reason', reason,
      'technician_released', case when to_status = 'MATCHING'
                                  then target.assigned_technician_id end
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Disputes
-- ---------------------------------------------------------------------------

-- Records a decision on a dispute and, when asked, applies the outcome to the
-- job. The refund amount is the decision, not the refund: returning money is
-- a provider call that belongs to the payment Edge Functions, which read this
-- column. That is why the amount is bounded by what was actually paid.
create or replace function public.admin_update_dispute(
  dispute_id uuid,
  new_status public.dispute_status,
  resolution text default null,
  refund_amount_sen bigint default 0,
  request_outcome public.service_status default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  target public.disputes;
  job public.service_requests;
  paid_total bigint;
begin
  perform public.require_admin();

  select * into target from public.disputes d
   where d.id = admin_update_dispute.dispute_id
   for update;
  if not found then
    raise exception 'That dispute no longer exists.' using errcode = 'RT404';
  end if;

  if target.status in ('resolved', 'rejected') then
    raise exception 'That dispute has already been decided.' using errcode = 'RT409';
  end if;

  if new_status = 'open' then
    raise exception 'A dispute cannot be moved back to open.' using errcode = 'RT400';
  end if;

  refund_amount_sen := coalesce(refund_amount_sen, 0);
  if refund_amount_sen < 0 then
    raise exception 'A refund cannot be negative.' using errcode = 'RT400';
  end if;

  select coalesce(sum(p.amount_sen), 0) into paid_total
    from public.payments p
   where p.request_id = target.request_id and p.status = 'paid';

  if refund_amount_sen > paid_total then
    raise exception 'The refund cannot be more than the RM% that was paid.',
      to_char(paid_total / 100.0, 'FM999999990.00') using errcode = 'RT400';
  end if;

  if new_status = 'under_review' then
    if request_outcome is not null or refund_amount_sen > 0 then
      raise exception 'Outcomes and refunds are set when the dispute is decided.'
        using errcode = 'RT400';
    end if;

    update public.disputes d set status = 'under_review' where d.id = target.id;
  else
    resolution := public.admin_require_reason(resolution, 10);
    if new_status = 'rejected' and refund_amount_sen > 0 then
      raise exception 'A rejected dispute cannot carry a refund.' using errcode = 'RT400';
    end if;

    update public.disputes d
       set status = new_status,
           resolution = admin_update_dispute.resolution,
           resolved_by = auth.uid(),
           resolved_at = now(),
           refund_amount_sen = admin_update_dispute.refund_amount_sen
     where d.id = target.id;
  end if;

  select * into job from public.service_requests r where r.id = target.request_id;

  -- Deciding the last open dispute on a job that is parked in DISPUTED has to
  -- say where the job goes next. Otherwise it stays parked forever: only an
  -- administrator can move it out, and nothing would prompt anyone to.
  if new_status in ('resolved', 'rejected')
     and request_outcome is null
     and job.status = 'DISPUTED'
     and not exists (
       select 1 from public.disputes d
        where d.request_id = target.request_id
          and d.id <> target.id
          and d.status in ('open', 'under_review')
     ) then
    raise exception 'Choose what happens to job % now that its dispute is decided.',
      job.reference using errcode = 'RT400';
  end if;

  if request_outcome is not null then
    if job.status <> 'DISPUTED' then
      raise exception 'The job is no longer under dispute, so it has no outcome to apply.'
        using errcode = 'RT409';
    end if;

    perform public.admin_transition_service_request(
      target.request_id, request_outcome,
      'Dispute ' || new_status::text || ': ' || coalesce(resolution, ''));
  end if;

  perform public.admin_notify(
    target.raised_by,
    'dispute_updated',
    case new_status
      when 'under_review' then 'Your dispute is being reviewed'
      when 'resolved' then 'Your dispute has been resolved'
      else 'Your dispute was not upheld'
    end,
    coalesce(resolution, 'A ReadyTech administrator is looking at the evidence.'),
    jsonb_build_object('dispute_id', target.id, 'request_id', target.request_id)
  );

  perform public.admin_log(
    'dispute.' || new_status::text,
    'disputes',
    target.id::text,
    jsonb_build_object(
      'request_id', target.request_id,
      'from', target.status,
      'to', new_status,
      'resolution', resolution,
      'refund_amount_sen', refund_amount_sen,
      'request_outcome', request_outcome
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Roles
-- ---------------------------------------------------------------------------

create or replace function public.admin_set_user_role(
  user_id uuid,
  new_role public.user_role,
  reason text
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  current_role_value public.user_role;
begin
  perform public.require_admin();
  reason := public.admin_require_reason(reason, 5);

  -- The last guard against an administrator locking everyone out, or quietly
  -- demoting themselves to cover a trail. Another admin has to do it.
  if user_id = auth.uid() then
    raise exception 'You cannot change your own role.' using errcode = 'RT403';
  end if;

  select r.role into current_role_value from public.user_roles r
   where r.user_id = admin_set_user_role.user_id
   for update;
  if not found then
    raise exception 'That account no longer exists.' using errcode = 'RT404';
  end if;

  if current_role_value = new_role then
    raise exception 'That account is already a %.', new_role using errcode = 'RT409';
  end if;

  -- A technician holding a live job cannot simply stop being one: the job
  -- would be bound to an account that no longer appears anywhere technicians
  -- are listed. Take them off the job first.
  if current_role_value = 'technician' and exists (
    select 1 from public.service_requests r
     where r.assigned_technician_id = admin_set_user_role.user_id
       and r.status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED')
  ) then
    raise exception 'This technician holds a live job. Reassign or cancel it first.'
      using errcode = 'RT409';
  end if;

  update public.user_roles r
     set role = new_role, assigned_by = auth.uid()
   where r.user_id = admin_set_user_role.user_id;

  if new_role = 'technician' then
    insert into public.technician_profiles (id) values (user_id)
    on conflict (id) do nothing;
  elsif current_role_value = 'technician' then
    -- The profile and its history stay - reviews and earnings refer to it -
    -- but it must stop being matchable.
    update public.technician_profiles t
       set is_available = false
     where t.id = admin_set_user_role.user_id;
  end if;

  perform public.admin_log(
    'user.role',
    'user_roles',
    user_id::text,
    jsonb_build_object('from', current_role_value, 'to', new_role, 'reason', reason)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Pricing
-- ---------------------------------------------------------------------------

-- The value must keep the shape it already has: every reader of pricing_config
-- (pricing_int, pricing_numeric, the matching weights) assumes it. A pricing
-- knob that silently became a string would surface as a broken quotation, far
-- from the edit that caused it.
create or replace function public.admin_set_pricing(
  config_key text,
  new_value jsonb
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  existing public.pricing_config;
  weight record;
begin
  perform public.require_admin();

  select * into existing from public.pricing_config p
   where p.key = config_key
   for update;
  if not found then
    raise exception 'There is no pricing setting called "%".', config_key
      using errcode = 'RT404';
  end if;

  if jsonb_typeof(new_value) is distinct from jsonb_typeof(existing.value) then
    raise exception 'That setting expects a %, not a %.',
      jsonb_typeof(existing.value), coalesce(jsonb_typeof(new_value), 'blank value')
      using errcode = 'RT400';
  end if;

  if jsonb_typeof(new_value) = 'number' then
    if (new_value #>> '{}')::numeric < 0 then
      raise exception 'Prices and limits cannot be negative.' using errcode = 'RT400';
    end if;

    -- Every *_sen key is money, and money is a whole number of sen.
    if config_key like '%\_sen' and (new_value #>> '{}')::numeric <> trunc((new_value #>> '{}')::numeric) then
      raise exception 'Amounts are whole sen.' using errcode = 'RT400';
    end if;

    if config_key = 'commission_percent' and (new_value #>> '{}')::numeric > 50 then
      raise exception 'Commission above 50%% is almost certainly a typing mistake.'
        using errcode = 'RT400';
    end if;
  end if;

  if jsonb_typeof(new_value) = 'object' then
    -- Weights may be retuned but not invented or dropped; the ranking query
    -- reads exactly these names.
    if (select array_agg(k order by k) from jsonb_object_keys(new_value) k)
       is distinct from
       (select array_agg(k order by k) from jsonb_object_keys(existing.value) k) then
      raise exception 'Keep the same set of fields; only their values can change.'
        using errcode = 'RT400';
    end if;

    for weight in select * from jsonb_each(new_value) loop
      if jsonb_typeof(weight.value) <> 'number' or (weight.value #>> '{}')::numeric < 0 then
        raise exception '"%" must be a number of zero or more.', weight.key
          using errcode = 'RT400';
      end if;
    end loop;
  end if;

  if new_value = existing.value then
    return;
  end if;

  update public.pricing_config p
     set value = new_value, updated_by = auth.uid()
   where p.key = config_key;

  perform public.admin_log(
    'pricing.update',
    'pricing_config',
    config_key,
    jsonb_build_object('from', existing.value, 'to', new_value)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Service catalogue
-- ---------------------------------------------------------------------------

-- Categories are edited directly by the console through their admin policy:
-- the table's own constraints already say everything that has to be true of
-- a row. This trigger is only the audit trail.
create or replace function public.audit_service_category_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- Migrations and the seed run without a user and are their own record.
  if auth.uid() is null then
    return null;
  end if;

  perform public.admin_log(
    'category.' || lower(tg_op),
    'service_categories',
    coalesce(new.id, old.id)::text,
    case tg_op
      when 'INSERT' then jsonb_build_object('to', to_jsonb(new))
      when 'DELETE' then jsonb_build_object('from', to_jsonb(old))
      else jsonb_build_object('from', to_jsonb(old), 'to', to_jsonb(new))
    end
  );
  return null;
end;
$$;

create trigger service_categories_audit
  after insert or update or delete on public.service_categories
  for each row execute function public.audit_service_category_change();

-- ---------------------------------------------------------------------------
-- Reviews and messages
-- ---------------------------------------------------------------------------

-- Removing a review moves a technician's average, which feeds matching. So it
-- is never silent: the review's full text is kept in the audit log, and the
-- rating trigger recomputes the average from what remains.
create or replace function public.admin_remove_review(
  review_id uuid,
  reason text
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  target public.reviews;
begin
  perform public.require_admin();
  reason := public.admin_require_reason(reason, 5);

  delete from public.reviews r
   where r.id = admin_remove_review.review_id
  returning * into target;

  if target.id is null then
    raise exception 'That review no longer exists.' using errcode = 'RT404';
  end if;

  perform public.admin_log(
    'review.remove',
    'reviews',
    target.id::text,
    jsonb_build_object('reason', reason, 'review', to_jsonb(target))
  );
end;
$$;

create or replace function public.admin_review_message_report(
  message_id uuid,
  redact boolean,
  reason text default null
)
returns void
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $$
declare
  target public.messages;
begin
  perform public.require_admin();
  if redact then
    reason := public.admin_require_reason(reason, 5);
  end if;

  select * into target from public.messages m
   where m.id = admin_review_message_report.message_id
   for update;
  if not found then
    raise exception 'That message no longer exists.' using errcode = 'RT404';
  end if;

  if target.reported_at is null then
    raise exception 'That message has not been reported.' using errcode = 'RT409';
  end if;

  if target.report_reviewed_at is not null then
    raise exception 'That report has already been reviewed.' using errcode = 'RT409';
  end if;

  -- Redaction replaces what the participants see. The original is kept in the
  -- audit log, so a dispute about what was said can still be settled.
  update public.messages m
     set report_reviewed_at = now(),
         report_reviewed_by = auth.uid(),
         kind = case when redact then 'system'::public.message_kind else m.kind end,
         body = case when redact then 'This message was removed by ReadyTech support.'
                     else m.body end,
         attachment_path = case when redact then null else m.attachment_path end
   where m.id = target.id;

  perform public.admin_log(
    case when redact then 'message.redact' else 'message.dismiss_report' end,
    'messages',
    target.id::text,
    jsonb_build_object(
      'request_id', target.request_id,
      'reason', reason,
      'reported_reason', target.reported_reason,
      'original', case when redact then to_jsonb(target) end
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Privileges
-- ---------------------------------------------------------------------------

-- 20260101001800 revoked everything and granted back an explicit set; new
-- objects follow the same rule rather than inheriting whatever the platform's
-- defaults happen to be.
revoke all on public.admin_audit_log from authenticated, anon;
grant select on public.admin_audit_log to authenticated;

revoke all on function public.require_admin() from public, anon, authenticated;
revoke all on function public.admin_log(text, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.admin_notify(uuid, public.notification_type, text, text, jsonb)
  from public, anon, authenticated;
revoke all on function public.admin_require_reason(text, integer) from public, anon, authenticated;
revoke all on function public.audit_service_category_change() from public, anon, authenticated;

-- Each of these checks require_admin() itself; EXECUTE only lets a caller ask.
revoke all on function public.admin_dashboard_stats() from public, anon;
revoke all on function public.admin_review_verification(uuid, public.verification_status, text) from public, anon;
revoke all on function public.admin_set_technician_status(uuid, public.verification_status, text) from public, anon;
revoke all on function public.admin_transition_service_request(uuid, public.service_status, text) from public, anon;
revoke all on function public.admin_update_dispute(uuid, public.dispute_status, text, bigint, public.service_status) from public, anon;
revoke all on function public.admin_set_user_role(uuid, public.user_role, text) from public, anon;
revoke all on function public.admin_set_pricing(text, jsonb) from public, anon;
revoke all on function public.admin_remove_review(uuid, text) from public, anon;
revoke all on function public.admin_review_message_report(uuid, boolean, text) from public, anon;

grant execute on function public.admin_dashboard_stats() to authenticated;
grant execute on function public.admin_review_verification(uuid, public.verification_status, text) to authenticated;
grant execute on function public.admin_set_technician_status(uuid, public.verification_status, text) to authenticated;
grant execute on function public.admin_transition_service_request(uuid, public.service_status, text) to authenticated;
grant execute on function public.admin_update_dispute(uuid, public.dispute_status, text, bigint, public.service_status) to authenticated;
grant execute on function public.admin_set_user_role(uuid, public.user_role, text) to authenticated;
grant execute on function public.admin_set_pricing(text, jsonb) to authenticated;
grant execute on function public.admin_remove_review(uuid, text) to authenticated;
grant execute on function public.admin_review_message_report(uuid, boolean, text) to authenticated;
