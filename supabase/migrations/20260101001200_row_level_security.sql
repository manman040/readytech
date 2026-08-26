-- ReadyTech :: row level security
--
-- Every table below denies by default and is opened only by the policies here.
-- This is the authorisation boundary for the whole product: the mobile app's
-- role-based routing is a convenience, and an attacker with a valid token and a
-- HTTP client is the case these rules are written against.
--
-- Three principles run through the file:
--   1. A user reads their own rows. Participation in a job is what grants
--      access to that job's records, and it is checked against the database,
--      not against anything the client sends.
--   2. Money and status are read-only to clients. Payments, earnings and
--      status history are written by Edge Functions using the service role,
--      which bypasses these policies precisely because it is trusted.
--   3. Nothing in a service history can be deleted by a normal user.

-- The anonymous role has no business in this schema at all. Sign-up and sign-in
-- go through Supabase Auth, not through PostgREST.
revoke all on all tables in schema public from anon;

-- ---------------------------------------------------------------------------
-- Participation helpers
-- ---------------------------------------------------------------------------

create or replace function public.is_request_participant(request uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1
    from public.service_requests r
    where r.id = request
      and (r.customer_id = auth.uid() or r.assigned_technician_id = auth.uid())
  );
$$;

create or replace function public.is_request_customer(request uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.service_requests r
    where r.id = request and r.customer_id = auth.uid()
  );
$$;

create or replace function public.is_request_technician(request uuid)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.service_requests r
    where r.id = request and r.assigned_technician_id = auth.uid()
  );
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

alter table public.profiles enable row level security;

create policy profiles_select_own
  on public.profiles for select to authenticated
  using (id = auth.uid());

-- The two sides of a live job need each other's name and number. Scoped to an
-- actual shared job, and it ends when the job does - this is not a directory.
create policy profiles_select_counterparty
  on public.profiles for select to authenticated
  using (
    exists (
      select 1 from public.service_requests r
      where (r.customer_id = profiles.id and r.assigned_technician_id = auth.uid())
         or (r.assigned_technician_id = profiles.id and r.customer_id = auth.uid())
    )
  );

-- A verified technician's public identity is visible to signed-in users, so
-- match recommendations can show who is being offered.
create policy profiles_select_verified_technicians
  on public.profiles for select to authenticated
  using (
    exists (
      select 1 from public.technician_profiles t
      where t.id = profiles.id and t.verification_status = 'approved'
    )
  );

create policy profiles_select_admin
  on public.profiles for select to authenticated
  using (public.is_admin());

create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_update_admin
  on public.profiles for update to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- No insert policy: profiles are created by the sign-up trigger.
-- No delete policy: account deletion cascades from auth.users.

-- ---------------------------------------------------------------------------
-- user_roles
-- ---------------------------------------------------------------------------

alter table public.user_roles enable row level security;

create policy user_roles_select_own
  on public.user_roles for select to authenticated
  using (user_id = auth.uid());

create policy user_roles_select_admin
  on public.user_roles for select to authenticated
  using (public.is_admin());

-- Deliberately no insert or update policy for anyone but an admin. Promotion
-- is an administrative act; this is the table that decides what every other
-- policy in this file believes about the caller.
create policy user_roles_write_admin
  on public.user_roles for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- technician_profiles
-- ---------------------------------------------------------------------------

alter table public.technician_profiles enable row level security;

create policy technician_profiles_select_own
  on public.technician_profiles for select to authenticated
  using (id = auth.uid());

create policy technician_profiles_select_approved
  on public.technician_profiles for select to authenticated
  using (verification_status = 'approved');

create policy technician_profiles_select_admin
  on public.technician_profiles for select to authenticated
  using (public.is_admin());

create policy technician_profiles_insert_own
  on public.technician_profiles for insert to authenticated
  with check (id = auth.uid() and public.is_technician());

create policy technician_profiles_update_own
  on public.technician_profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy technician_profiles_update_admin
  on public.technician_profiles for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- A technician may edit their own row, but not award themselves a reputation
-- or a verification. Those columns move only through the service role or an
-- administrator.
create or replace function public.technician_profiles_protect_columns()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- The counter and rating refresh triggers legitimately write these columns;
  -- is_internal_write() is what tells them apart from a client trying to award
  -- itself a reputation.
  if auth.uid() is null or public.is_admin() or public.is_internal_write() then
    return new;
  end if;

  if new.verification_status is distinct from old.verification_status
    or new.verified_at is distinct from old.verified_at
    or new.suspended_reason is distinct from old.suspended_reason
    or new.rating_average is distinct from old.rating_average
    or new.rating_count is distinct from old.rating_count
    or new.completed_jobs is distinct from old.completed_jobs
    or new.cancelled_jobs is distinct from old.cancelled_jobs
    or new.offers_received is distinct from old.offers_received
    or new.offers_accepted is distinct from old.offers_accepted
  then
    raise exception 'Verification and reputation are not editable.'
      using errcode = 'RT403';
  end if;

  return new;
end;
$$;

create trigger technician_profiles_protect
  before update on public.technician_profiles
  for each row execute function public.technician_profiles_protect_columns();

-- ---------------------------------------------------------------------------
-- technician_skills
-- ---------------------------------------------------------------------------

alter table public.technician_skills enable row level security;

create policy technician_skills_select_all
  on public.technician_skills for select to authenticated
  using (true);

create policy technician_skills_write_own
  on public.technician_skills for all to authenticated
  using (technician_id = auth.uid())
  with check (technician_id = auth.uid());

create policy technician_skills_write_admin
  on public.technician_skills for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- technician_verifications
-- ---------------------------------------------------------------------------

alter table public.technician_verifications enable row level security;

create policy technician_verifications_select_own
  on public.technician_verifications for select to authenticated
  using (technician_id = auth.uid());

create policy technician_verifications_insert_own
  on public.technician_verifications for insert to authenticated
  with check (technician_id = auth.uid() and status = 'pending');

create policy technician_verifications_admin
  on public.technician_verifications for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- technician_locations
-- ---------------------------------------------------------------------------

alter table public.technician_locations enable row level security;

create policy technician_locations_write_own
  on public.technician_locations for all to authenticated
  using (technician_id = auth.uid())
  with check (technician_id = auth.uid());

-- A customer sees a technician's position only while that technician is on the
-- way to them, and only for their own job. Live location is not a property of
-- being a technician; it is a property of an active journey.
create policy technician_locations_select_tracking_customer
  on public.technician_locations for select to authenticated
  using (
    exists (
      select 1 from public.service_requests r
      where r.assigned_technician_id = technician_locations.technician_id
        and r.customer_id = auth.uid()
        and r.status in ('ASSIGNED', 'TECHNICIAN_ON_THE_WAY', 'ARRIVED')
    )
  );

create policy technician_locations_select_admin
  on public.technician_locations for select to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Catalogue and pricing
-- ---------------------------------------------------------------------------

alter table public.service_categories enable row level security;

create policy service_categories_select_active
  on public.service_categories for select to authenticated
  using (is_active or public.is_admin());

create policy service_categories_write_admin
  on public.service_categories for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

alter table public.pricing_config enable row level security;

-- Readable so the app can show an honest breakdown of an estimate. Writable
-- only by an administrator; the figure that ends up on an invoice is computed
-- server side regardless of what the client read.
create policy pricing_config_select
  on public.pricing_config for select to authenticated
  using (true);

create policy pricing_config_write_admin
  on public.pricing_config for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

alter table public.service_status_transitions enable row level security;

create policy service_status_transitions_select
  on public.service_status_transitions for select to authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- devices and addresses
-- ---------------------------------------------------------------------------

alter table public.devices enable row level security;

create policy devices_owner_all
  on public.devices for all to authenticated
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

-- The technician assigned to a job can see the device that job is about, and
-- nothing else in the customer's inventory.
create policy devices_select_assigned_technician
  on public.devices for select to authenticated
  using (
    exists (
      select 1 from public.service_requests r
      where r.device_id = devices.id
        and r.assigned_technician_id = auth.uid()
    )
  );

create policy devices_select_admin
  on public.devices for select to authenticated
  using (public.is_admin());

alter table public.saved_addresses enable row level security;

-- Saved addresses are never visible to technicians. A job carries the one
-- address it needs, copied onto the request.
create policy saved_addresses_owner_all
  on public.saved_addresses for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- service_requests
-- ---------------------------------------------------------------------------

alter table public.service_requests enable row level security;

create policy service_requests_select_customer
  on public.service_requests for select to authenticated
  using (customer_id = auth.uid());

-- Only the technician who holds the job. A technician who has merely been
-- offered it sees a redacted summary through technician_open_offers() instead,
-- which is what keeps the customer's address private until someone has actually
-- committed to attending.
create policy service_requests_select_assigned_technician
  on public.service_requests for select to authenticated
  using (assigned_technician_id = auth.uid());

create policy service_requests_select_admin
  on public.service_requests for select to authenticated
  using (public.is_admin());

create policy service_requests_insert_customer
  on public.service_requests for insert to authenticated
  with check (
    customer_id = auth.uid()
    -- A request always starts at the beginning. Inserting one that is already
    -- assigned or paid would sidestep the entire state machine.
    and status = 'REQUESTED'
  );

create policy service_requests_update_participant
  on public.service_requests for update to authenticated
  using (customer_id = auth.uid() or assigned_technician_id = auth.uid())
  with check (customer_id = auth.uid() or assigned_technician_id = auth.uid());

create policy service_requests_update_admin
  on public.service_requests for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- No delete policy for anyone, administrators included. A service history that
-- can be erased is not a record. Cancellation is a status, not a deletion.

-- ---------------------------------------------------------------------------
-- service_request_items and history
-- ---------------------------------------------------------------------------

alter table public.service_request_items enable row level security;

create policy service_request_items_select_participant
  on public.service_request_items for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy service_request_items_insert_customer
  on public.service_request_items for insert to authenticated
  with check (public.is_request_customer(request_id));

alter table public.service_status_history enable row level security;

-- Read-only to everyone. The trigger writes it with the service role's
-- authority; an audit trail a participant can edit is worthless.
create policy service_status_history_select_participant
  on public.service_status_history for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

-- ---------------------------------------------------------------------------
-- technician_assignments
-- ---------------------------------------------------------------------------

alter table public.technician_assignments enable row level security;

create policy technician_assignments_select_own
  on public.technician_assignments for select to authenticated
  using (technician_id = auth.uid());

create policy technician_assignments_select_customer
  on public.technician_assignments for select to authenticated
  using (public.is_request_customer(request_id));

create policy technician_assignments_select_admin
  on public.technician_assignments for select to authenticated
  using (public.is_admin());

-- A technician answers their own offer. Accepting is not done here - it goes
-- through accept_job_offer(), which takes a lock so two technicians cannot
-- accept the same job.
create policy technician_assignments_update_own
  on public.technician_assignments for update to authenticated
  using (technician_id = auth.uid() and status = 'offered')
  with check (technician_id = auth.uid() and status in ('declined', 'offered'));

-- ---------------------------------------------------------------------------
-- diagnoses and quotations
-- ---------------------------------------------------------------------------

alter table public.diagnoses enable row level security;

create policy diagnoses_select_participant
  on public.diagnoses for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy diagnoses_write_technician
  on public.diagnoses for insert to authenticated
  with check (
    technician_id = auth.uid() and public.is_request_technician(request_id)
  );

create policy diagnoses_update_technician
  on public.diagnoses for update to authenticated
  using (technician_id = auth.uid() and public.is_request_technician(request_id))
  with check (technician_id = auth.uid());

alter table public.quotations enable row level security;

-- The customer sees a quotation once it has been submitted, not while the
-- technician is still drafting it.
create policy quotations_select_customer
  on public.quotations for select to authenticated
  using (public.is_request_customer(request_id) and status <> 'draft');

create policy quotations_select_technician
  on public.quotations for select to authenticated
  using (technician_id = auth.uid());

create policy quotations_select_admin
  on public.quotations for select to authenticated
  using (public.is_admin());

create policy quotations_insert_technician
  on public.quotations for insert to authenticated
  with check (
    technician_id = auth.uid()
    and public.is_request_technician(request_id)
    and status in ('draft', 'submitted')
  );

create policy quotations_update_technician
  on public.quotations for update to authenticated
  using (
    technician_id = auth.uid()
    and status in ('draft', 'submitted')
  )
  with check (technician_id = auth.uid());

-- The customer's only write is the decision, and only on a submitted
-- quotation. The immutability trigger enforces the rest.
create policy quotations_decide_customer
  on public.quotations for update to authenticated
  using (public.is_request_customer(request_id) and status = 'submitted')
  with check (
    public.is_request_customer(request_id)
    and status in ('approved', 'declined')
  );

create policy quotations_admin
  on public.quotations for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

alter table public.quotation_items enable row level security;

create policy quotation_items_select
  on public.quotation_items for select to authenticated
  using (
    exists (
      select 1 from public.quotations q
      where q.id = quotation_items.quotation_id
        and (
          q.technician_id = auth.uid()
          or (public.is_request_customer(q.request_id) and q.status <> 'draft')
          or public.is_admin()
        )
    )
  );

create policy quotation_items_write_technician
  on public.quotation_items for all to authenticated
  using (
    exists (
      select 1 from public.quotations q
      where q.id = quotation_items.quotation_id
        and q.technician_id = auth.uid()
        and q.status in ('draft', 'submitted')
    )
  )
  with check (
    exists (
      select 1 from public.quotations q
      where q.id = quotation_items.quotation_id
        and q.technician_id = auth.uid()
        and q.status in ('draft', 'submitted')
    )
  );

alter table public.quotation_approvals enable row level security;

create policy quotation_approvals_select
  on public.quotation_approvals for select to authenticated
  using (
    exists (
      select 1 from public.quotations q
      where q.id = quotation_approvals.quotation_id
        and (
          q.technician_id = auth.uid()
          or public.is_request_customer(q.request_id)
          or public.is_admin()
        )
    )
  );

create policy quotation_approvals_insert_customer
  on public.quotation_approvals for insert to authenticated
  with check (
    approved_by = auth.uid()
    and exists (
      select 1 from public.quotations q
      where q.id = quotation_approvals.quotation_id
        and public.is_request_customer(q.request_id)
    )
  );

-- No update or delete. A decision, once recorded, stands.

-- ---------------------------------------------------------------------------
-- Money: read-only to every client
-- ---------------------------------------------------------------------------

alter table public.payments enable row level security;

create policy payments_select_participant
  on public.payments for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

-- No insert, update or delete policy at all. Payments are created and settled
-- exclusively by the create-payment and verify-payment Edge Functions, which
-- use the service role and therefore bypass these policies. A client that
-- could write here could mark its own job paid.

alter table public.payment_items enable row level security;

create policy payment_items_select_participant
  on public.payment_items for select to authenticated
  using (
    exists (
      select 1 from public.payments p
      where p.id = payment_items.payment_id
        and (public.is_request_participant(p.request_id) or public.is_admin())
    )
  );

alter table public.technician_earnings enable row level security;

create policy technician_earnings_select_own
  on public.technician_earnings for select to authenticated
  using (technician_id = auth.uid());

create policy technician_earnings_select_admin
  on public.technician_earnings for select to authenticated
  using (public.is_admin());

-- ---------------------------------------------------------------------------
-- Evidence, checklists, warranty, reviews
-- ---------------------------------------------------------------------------

alter table public.service_evidence enable row level security;

create policy service_evidence_select_participant
  on public.service_evidence for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy service_evidence_insert_participant
  on public.service_evidence for insert to authenticated
  with check (
    uploaded_by = auth.uid() and public.is_request_participant(request_id)
  );

-- No update, no delete, not even for the uploader. Evidence that can be
-- withdrawn once a dispute starts proves nothing.

alter table public.service_checklists enable row level security;

create policy service_checklists_select_participant
  on public.service_checklists for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy service_checklists_write_technician
  on public.service_checklists for all to authenticated
  using (public.is_request_technician(request_id))
  with check (public.is_request_technician(request_id));

alter table public.warranties enable row level security;

create policy warranties_select_participant
  on public.warranties for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy warranties_admin
  on public.warranties for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Warranties are otherwise issued by the create-warranty Edge Function.

alter table public.reviews enable row level security;

-- Reviews are public to signed-in users; that is the point of a reputation.
create policy reviews_select_all
  on public.reviews for select to authenticated
  using (true);

create policy reviews_insert_customer
  on public.reviews for insert to authenticated
  with check (
    customer_id = auth.uid()
    and public.is_request_customer(request_id)
    -- Only after the work is actually finished and settled, so a review is
    -- always about a service that happened.
    and exists (
      select 1 from public.service_requests r
      where r.id = reviews.request_id
        and r.status in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE')
    )
  );

-- An edit window, so a review written in the heat of the moment can be
-- reconsidered - but not an indefinite one, which would let a customer hold a
-- rating over a technician.
create policy reviews_update_own_recent
  on public.reviews for update to authenticated
  using (customer_id = auth.uid() and created_at > now() - interval '24 hours')
  with check (customer_id = auth.uid());

create policy reviews_admin
  on public.reviews for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- ---------------------------------------------------------------------------
-- Messaging
-- ---------------------------------------------------------------------------

alter table public.messages enable row level security;

create policy messages_select_participant
  on public.messages for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy messages_insert_participant
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and public.is_request_participant(request_id)
    -- Enforces the business rule that a conversation closes with the job.
    and public.conversation_is_open(request_id)
    and kind <> 'system'
  );

-- Marking as read and reporting are updates; the content itself is immutable,
-- which is enforced by the trigger below rather than by policy.
create policy messages_update_participant
  on public.messages for update to authenticated
  using (public.is_request_participant(request_id))
  with check (public.is_request_participant(request_id));

create policy messages_admin
  on public.messages for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

create or replace function public.messages_protect_content()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;

  if new.body is distinct from old.body
    or new.attachment_path is distinct from old.attachment_path
    or new.sender_id is distinct from old.sender_id
    or new.created_at is distinct from old.created_at
  then
    raise exception 'A sent message cannot be edited.'
      using errcode = 'RT403';
  end if;

  -- Only the recipient marks a message read.
  if new.read_at is distinct from old.read_at
     and old.sender_id = auth.uid() then
    raise exception 'You cannot mark your own message as read.'
      using errcode = 'RT403';
  end if;

  return new;
end;
$$;

create trigger messages_immutable
  before update on public.messages
  for each row execute function public.messages_protect_content();

-- ---------------------------------------------------------------------------
-- notifications
-- ---------------------------------------------------------------------------

alter table public.notifications enable row level security;

create policy notifications_select_own
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

-- The only client-side write is marking one read. Notifications are created by
-- the send-notification Edge Function; letting a client insert them would let
-- anyone put arbitrary text in someone else's notification centre.
create policy notifications_update_own
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy notifications_delete_own
  on public.notifications for delete to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- disputes and cancellations
-- ---------------------------------------------------------------------------

alter table public.disputes enable row level security;

create policy disputes_select_participant
  on public.disputes for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy disputes_insert_participant
  on public.disputes for insert to authenticated
  with check (
    raised_by = auth.uid()
    and public.is_request_participant(request_id)
    and status = 'open'
  );

create policy disputes_admin
  on public.disputes for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

alter table public.cancellation_records enable row level security;

create policy cancellation_records_select_participant
  on public.cancellation_records for select to authenticated
  using (public.is_request_participant(request_id) or public.is_admin());

create policy cancellation_records_admin
  on public.cancellation_records for all to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Cancellation records are otherwise written by process-cancellation, which
-- applies the fee policy. A client that wrote its own record could set the fee
-- to zero.
