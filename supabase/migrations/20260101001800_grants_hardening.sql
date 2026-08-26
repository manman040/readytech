-- ReadyTech :: make privileges deterministic
--
-- 20260101001600 granted privileges but never revoked any, which left the
-- result dependent on whatever the platform's default privileges happened to
-- be. That turned out to differ between environments: locally `authenticated`
-- began with almost nothing, so the intended least-privilege set was what took
-- effect; on a hosted project it begins with a broad grant, so the narrow
-- grants were a no-op and `authenticated` retained INSERT on tables it must
-- never write.
--
-- Row Level Security still refused those writes - a hosted client attempting
-- to insert a payment was rejected by policy - so nothing was exposed. But the
-- privilege layer is meant to be the backstop *underneath* the policies, and a
-- backstop that only exists in development is not a backstop.
--
-- So: revoke everything from `authenticated` in this schema, then grant back
-- exactly the intended set. The result no longer depends on where the database
-- came from.
--
-- This supersedes the grants in 20260101001600; that file is left as applied
-- history rather than edited, since it has already run.

revoke all on all tables in schema public from authenticated;
revoke all on all functions in schema public from authenticated;
revoke all on all sequences in schema public from authenticated;

revoke all on all tables in schema public from anon;
revoke all on all functions in schema public from anon;
revoke all on all sequences in schema public from anon;

grant usage on schema public to authenticated;
grant usage on schema extensions to authenticated;

-- Read-only to every client
-- ---------------------------------------------------------------------------

-- Money and audit trails. Written exclusively by Edge Functions holding the
-- service role, and by triggers.
grant select on public.payments to authenticated;
grant select on public.payment_items to authenticated;
grant select on public.technician_earnings to authenticated;
grant select on public.service_status_history to authenticated;

-- The state machine itself, so a client can render what is possible next.
grant select on public.service_status_transitions to authenticated;

-- ---------------------------------------------------------------------------
-- Read and append
-- ---------------------------------------------------------------------------

-- Evidence is append-only: no UPDATE, no DELETE, not even for the uploader.
-- Evidence that can be withdrawn once a dispute starts proves nothing.
grant select, insert on public.service_evidence to authenticated;

-- A decision, once recorded, stands.
grant select, insert on public.quotation_approvals to authenticated;

-- The answers to the follow-up questions, captured with the request.
grant select, insert on public.service_request_items to authenticated;

-- ---------------------------------------------------------------------------
-- Read and write, filtered by policy
-- ---------------------------------------------------------------------------

grant select, update on public.profiles to authenticated;
grant select, insert, update, delete on public.user_roles to authenticated;

grant select, insert, update, delete on public.technician_profiles to authenticated;
grant select, insert, update, delete on public.technician_skills to authenticated;
grant select, insert, update, delete on public.technician_verifications to authenticated;
grant select, insert, update, delete on public.technician_locations to authenticated;
grant select, update on public.technician_assignments to authenticated;

grant select, insert, update, delete on public.devices to authenticated;
grant select, insert, update, delete on public.saved_addresses to authenticated;

grant select, insert, update, delete on public.service_categories to authenticated;
grant select, insert, update, delete on public.pricing_config to authenticated;

-- No DELETE. A service history that can be erased is not a record.
grant select, insert, update on public.service_requests to authenticated;

grant select, insert, update, delete on public.diagnoses to authenticated;
grant select, insert, update, delete on public.quotations to authenticated;
grant select, insert, update, delete on public.quotation_items to authenticated;

grant select, insert, update, delete on public.service_checklists to authenticated;
grant select, insert, update, delete on public.warranties to authenticated;
grant select, insert, update, delete on public.reviews to authenticated;

grant select, insert, update, delete on public.messages to authenticated;
grant select, update, delete on public.notifications to authenticated;

grant select, insert, update, delete on public.disputes to authenticated;
grant select, insert, update, delete on public.cancellation_records to authenticated;

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------

-- Policy helpers. A policy expression is evaluated as the querying user, so
-- without EXECUTE here every policy that calls one of these fails closed and
-- the whole schema becomes unreadable.
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_admin() to authenticated;
grant execute on function public.is_technician() to authenticated;
grant execute on function public.is_request_participant(uuid) to authenticated;
grant execute on function public.is_request_customer(uuid) to authenticated;
grant execute on function public.is_request_technician(uuid) to authenticated;
grant execute on function public.conversation_is_open(uuid) to authenticated;
grant execute on function public.technician_is_matchable(uuid) to authenticated;

-- Pricing lookups, so the app can show an honest breakdown.
grant execute on function public.pricing_int(text) to authenticated;
grant execute on function public.pricing_numeric(text) to authenticated;
grant execute on function
  public.estimate_service_cost(uuid, public.urgency_level, numeric)
  to authenticated;

-- Lifecycle operations. Each performs its own authorisation check internally,
-- which is why they are SECURITY DEFINER and why the tables they write are not
-- directly writable for the same operation.
grant execute on function public.active_service_request() to authenticated;
grant execute on function public.verify_arrival_code(uuid, text) to authenticated;
grant execute on function public.accept_job_offer(uuid) to authenticated;
grant execute on function public.decline_job_offer(uuid, text) to authenticated;

-- The redacted offer feed. This exists precisely so a technician who has only
-- been offered a job needs no select privilege on service_requests.
grant execute on function public.technician_open_offers() to authenticated;

-- Matching. Restricted to the job's own customer and to administrators by a
-- check inside the function.
grant execute on function public.rank_technicians(uuid, numeric, integer)
  to authenticated;

-- Deliberately not granted: calculate_commission() and the trigger functions.
-- Commission is computed by release-payment under the service role, and a
-- trigger function does not require EXECUTE to fire.
