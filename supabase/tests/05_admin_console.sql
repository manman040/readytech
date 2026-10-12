\pset pager off
-- The administrator console's backend, exercised as the people who would call
-- it: an administrator, and the customers and technicians who must not be able
-- to. Every block acts as a real signed-in user, so the is_admin() checks, the
-- status guard and the column guards are genuinely in play. Everything here is
-- rolled back.
--
-- Run after `supabase db reset`:
--   docker exec -i supabase_db_readytech psql -U postgres -d postgres -q \
--     < supabase/tests/05_admin_console.sql

\set admin    '{"sub":"33333333-3333-4333-8333-000000000001","role":"authenticated"}'
\set adam     '{"sub":"11111111-1111-4111-8111-000000000001","role":"authenticated"}'
\set ahmad    '{"sub":"22222222-2222-4222-8222-000000000001","role":"authenticated"}'

begin;

\echo '=== A. NOBODY BUT AN ADMINISTRATOR ==='

select set_config('request.jwt.claims', :'adam', true);
set local role authenticated;

do $$ begin
  perform public.admin_dashboard_stats();
  raise notice 'A1 FAIL customer read the dashboard';
exception when others then
  if sqlstate = 'RT403' then raise notice 'A1 PASS customer refused the dashboard';
  else raise notice 'A1 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ begin
  perform public.admin_set_user_role(auth.uid(), 'admin', 'I would like to be one');
  raise notice 'A2 FAIL customer promoted themselves';
exception when others then
  if sqlstate = 'RT403' then raise notice 'A2 PASS customer cannot promote themselves';
  else raise notice 'A2 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ declare n int; begin
  select count(*) into n from public.admin_audit_log;
  if n = 0 then raise notice 'A3 PASS customer sees no audit log';
  else raise notice 'A3 FAIL customer sees % audit rows', n; end if;
end $$;

do $$ begin
  insert into public.admin_audit_log (action, target_table, target_id)
  values ('forged.entry', 'x', 'x');
  raise notice 'A4 FAIL customer wrote to the audit log';
exception when others then raise notice 'A4 PASS audit log not writable: %', sqlerrm; end $$;

select set_config('request.jwt.claims', :'ahmad', true);

do $$ begin
  perform public.admin_set_technician_status(auth.uid(), 'approved');
  raise notice 'A5 FAIL technician changed their own verification';
exception when others then
  if sqlstate = 'RT403' then raise notice 'A5 PASS technician refused';
  else raise notice 'A5 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ begin
  perform public.admin_set_pricing('commission_percent', '0');
  raise notice 'A6 FAIL technician set the commission';
exception when others then
  if sqlstate = 'RT403' then raise notice 'A6 PASS technician cannot touch pricing';
  else raise notice 'A6 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

\echo ''
\echo '=== B. DASHBOARD AND VERIFICATION ==='

select set_config('request.jwt.claims', :'admin', true);

do $$ declare s jsonb; begin
  s := public.admin_dashboard_stats();
  if (s ->> 'jobs_total')::int = 5 and (s ->> 'documents_pending')::int = 1
     and (s -> 'jobs_by_status' ->> 'MATCHING')::int = 1 then
    raise notice 'B1 PASS dashboard: % jobs, % document pending, % paid sen',
      s ->> 'jobs_total', s ->> 'documents_pending', s ->> 'gross_paid_sen_total';
  else raise notice 'B1 FAIL unexpected stats %', s; end if;
exception when others then raise notice 'B1 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare doc uuid; begin
  select id into doc from public.technician_verifications where status = 'pending' limit 1;
  perform public.admin_review_verification(doc, 'rejected', 'no');
  raise notice 'B2 FAIL rejected without a usable reason';
exception when others then
  if sqlstate = 'RT400' then raise notice 'B2 PASS rejection needs a reason';
  else raise notice 'B2 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ declare doc uuid; st public.verification_status; notes int; begin
  select id into doc from public.technician_verifications where status = 'pending' limit 1;
  perform public.admin_review_verification(doc, 'approved', null);
  select verification_status into st from public.technician_profiles
   where id = '22222222-2222-4222-8222-000000000009';
  -- Notifications are not readable by an admin; count them as the owner would.
  select count(*) into notes from public.admin_audit_log
   where action = 'verification.approved' and target_id = doc::text;
  if st = 'approved' and notes = 1 then
    raise notice 'B3 PASS document approved -> technician approved, audited';
  else raise notice 'B3 FAIL status=% audit rows=%', st, notes; end if;
exception when others then raise notice 'B3 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare doc uuid; begin
  select id into doc from public.technician_verifications
   where technician_id = '22222222-2222-4222-8222-000000000009' limit 1;
  perform public.admin_review_verification(doc, 'approved', null);
  raise notice 'B4 FAIL reviewed twice';
exception when others then
  if sqlstate = 'RT409' then raise notice 'B4 PASS a document is reviewed once';
  else raise notice 'B4 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ begin
  perform public.admin_set_technician_status(
    '22222222-2222-4222-8222-000000000001', 'suspended', 'Repeated no-shows reported by customers');
  if public.technician_is_matchable('22222222-2222-4222-8222-000000000001') then
    raise notice 'B5 FAIL suspended technician still matchable';
  elsif exists (select 1 from public.technician_profiles
                 where id = '22222222-2222-4222-8222-000000000001'
                   and suspended_reason is not null and not is_available) then
    raise notice 'B5 PASS suspended: unavailable, unmatchable, reason recorded';
  else raise notice 'B5 FAIL suspension incomplete'; end if;
exception when others then raise notice 'B5 FAIL [%] %', sqlstate, sqlerrm; end $$;

\echo ''
\echo '=== C. THE NOTIFIED TECHNICIAN SEES IT ==='

select set_config('request.jwt.claims', :'ahmad', true);

do $$ declare n int; begin
  select count(*) into n from public.notifications
   where user_id = auth.uid() and type = 'verification_updated';
  if n = 1 then raise notice 'C1 PASS suspended technician was notified';
  else raise notice 'C1 FAIL % notifications', n; end if;
end $$;

\echo ''
\echo '=== D. ROLES ==='

select set_config('request.jwt.claims', :'admin', true);

do $$ begin
  perform public.admin_set_user_role(auth.uid(), 'customer', 'Stepping down today');
  raise notice 'D1 FAIL admin changed their own role';
exception when others then
  if sqlstate = 'RT403' then raise notice 'D1 PASS cannot change own role';
  else raise notice 'D1 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

-- Mei (technician 4) holds RT-26-000002, which is still live.
do $$ begin
  perform public.admin_set_user_role(
    '22222222-2222-4222-8222-000000000004', 'customer', 'Leaving the platform');
  raise notice 'D2 FAIL demoted a technician holding a live job';
exception when others then
  if sqlstate = 'RT409' then raise notice 'D2 PASS live job blocks demotion';
  else raise notice 'D2 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ begin
  perform public.admin_set_user_role(
    '11111111-1111-4111-8111-000000000006', 'technician', 'Onboarded at the partner event');
  if exists (select 1 from public.technician_profiles
              where id = '11111111-1111-4111-8111-000000000006'
                and verification_status = 'unsubmitted') then
    raise notice 'D3 PASS promoted customer has an unverified technician profile';
  else raise notice 'D3 FAIL no technician profile'; end if;
exception when others then raise notice 'D3 FAIL [%] %', sqlstate, sqlerrm; end $$;

\echo ''
\echo '=== E. JOBS ==='

do $$ begin
  perform public.admin_transition_service_request(
    '66666666-0000-4000-8000-000000000004', 'COMPLETED', 'Customer says it is fine now');
  raise notice 'E1 FAIL admin completed a job that is still matching';
exception when others then
  if sqlstate = 'RT409' then raise notice 'E1 PASS transition table still decides';
  else raise notice 'E1 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

-- RT-26-000003: technician 2 is on the way. Send it back to matching.
do $$ declare r public.service_requests; h text; a public.assignment_status; begin
  perform public.admin_transition_service_request(
    '66666666-0000-4000-8000-000000000003', 'MATCHING', 'Technician vehicle broke down');
  select * into r from public.service_requests where id = '66666666-0000-4000-8000-000000000003';
  select reason into h from public.service_status_history
   where request_id = r.id order by created_at desc limit 1;
  select status into a from public.technician_assignments
   where request_id = r.id and technician_id = '22222222-2222-4222-8222-000000000002';
  if r.status = 'MATCHING' and r.assigned_technician_id is null
     and h = 'Technician vehicle broke down' and coalesce(a::text, 'withdrawn') = 'withdrawn' then
    raise notice 'E2 PASS back to matching, technician released, reason on the timeline';
  else raise notice 'E2 FAIL status=% tech=% reason=% offer=%', r.status, r.assigned_technician_id, h, a; end if;
exception when others then raise notice 'E2 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare c public.cancellation_records; begin
  perform public.admin_transition_service_request(
    '66666666-0000-4000-8000-000000000002', 'CANCELLED', 'Customer asked support to cancel');
  select * into c from public.cancellation_records
   where request_id = '66666666-0000-4000-8000-000000000002';
  if c.cancelled_by_role = 'admin' and c.fee_sen = 0 and c.fee_waived
     and c.status_at_cancellation = 'AWAITING_CUSTOMER_APPROVAL' then
    raise notice 'E3 PASS cancelled with a fee-free admin cancellation record';
  else raise notice 'E3 FAIL record %', c; end if;
exception when others then raise notice 'E3 FAIL [%] %', sqlstate, sqlerrm; end $$;

\echo ''
\echo '=== F. DISPUTES ==='

-- Adam disputes his finished job, as a customer can.
select set_config('request.jwt.claims', :'adam', true);

do $$ begin
  insert into public.disputes (request_id, raised_by, reason, description)
  values ('66666666-0000-4000-8000-000000000001', auth.uid(), 'repair_not_working',
          'The screen started flickering again two days after the repair.');
  update public.service_requests set status = 'DISPUTED'
   where id = '66666666-0000-4000-8000-000000000001';
  raise notice 'F0 setup: dispute raised by the customer';
exception when others then raise notice 'F0 FAIL [%] %', sqlstate, sqlerrm; end $$;

select set_config('request.jwt.claims', :'admin', true);

do $$ declare d uuid; begin
  select id into d from public.disputes where request_id = '66666666-0000-4000-8000-000000000001';
  perform public.admin_update_dispute(d, 'resolved', 'Technician will redo the repair under warranty.', 0, null);
  raise notice 'F1 FAIL decided with the job left parked in DISPUTED';
exception when others then
  if sqlstate = 'RT400' then raise notice 'F1 PASS deciding requires a job outcome';
  else raise notice 'F1 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ declare d uuid; begin
  select id into d from public.disputes where request_id = '66666666-0000-4000-8000-000000000001';
  perform public.admin_update_dispute(d, 'resolved', 'Refunding far more than was ever paid.', 999999999, 'WARRANTY_ACTIVE');
  raise notice 'F2 FAIL refund above the amount paid';
exception when others then
  if sqlstate = 'RT400' then raise notice 'F2 PASS refund bounded by payment: %', sqlerrm;
  else raise notice 'F2 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ declare d uuid; st public.service_status; ds public.dispute_status; begin
  select id into d from public.disputes where request_id = '66666666-0000-4000-8000-000000000001';
  perform public.admin_update_dispute(d, 'under_review');
  perform public.admin_update_dispute(d, 'resolved',
    'Technician will redo the display cable under warranty.', 1000, 'WARRANTY_ACTIVE');
  select status into st from public.service_requests where id = '66666666-0000-4000-8000-000000000001';
  select status into ds from public.disputes where id = d;
  if st = 'WARRANTY_ACTIVE' and ds = 'resolved' then
    raise notice 'F3 PASS dispute resolved, job returned to warranty';
  else raise notice 'F3 FAIL job=% dispute=%', st, ds; end if;
exception when others then raise notice 'F3 FAIL [%] %', sqlstate, sqlerrm; end $$;

\echo ''
\echo '=== G. PRICING ==='

do $$ begin
  perform public.admin_set_pricing('commission_percent', '"ten"');
  raise notice 'G1 FAIL commission became a string';
exception when others then
  if sqlstate = 'RT400' then raise notice 'G1 PASS type preserved';
  else raise notice 'G1 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ begin
  perform public.admin_set_pricing('platform_fee_sen', '10.5');
  raise notice 'G2 FAIL fractional sen accepted';
exception when others then
  if sqlstate = 'RT400' then raise notice 'G2 PASS money is whole sen';
  else raise notice 'G2 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ begin
  perform public.admin_set_pricing('matching_weights', '{"distance": 100}');
  raise notice 'G3 FAIL weights reshaped';
exception when others then
  if sqlstate = 'RT400' then raise notice 'G3 PASS weights keep their fields';
  else raise notice 'G3 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

do $$ declare by_whom uuid; begin
  perform public.admin_set_pricing('commission_percent', '12.5');
  select updated_by into by_whom from public.pricing_config where key = 'commission_percent';
  if public.pricing_numeric('commission_percent') = 12.5 and by_whom = auth.uid() then
    raise notice 'G4 PASS commission updated and attributed';
  else raise notice 'G4 FAIL value=% by=%', public.pricing_numeric('commission_percent'), by_whom; end if;
exception when others then raise notice 'G4 FAIL [%] %', sqlstate, sqlerrm; end $$;

\echo ''
\echo '=== H. CATALOGUE, REVIEWS, MESSAGES ==='

do $$ declare n int; begin
  update public.service_categories set diagnosis_fee_sen = 2500
   where id = '44444444-0000-4000-8000-000000000001';
  select count(*) into n from public.admin_audit_log
   where action = 'category.update' and target_id = '44444444-0000-4000-8000-000000000001';
  if n = 1 then raise notice 'H1 PASS category edit audited';
  else raise notice 'H1 FAIL % audit rows', n; end if;
exception when others then raise notice 'H1 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rv uuid; kept jsonb; begin
  select id into rv from public.reviews limit 1;
  perform public.admin_remove_review(rv, 'Contains the technician''s phone number');
  select detail -> 'review' into kept from public.admin_audit_log
   where action = 'review.remove' and target_id = rv::text;
  if not exists (select 1 from public.reviews where id = rv) and kept ->> 'id' = rv::text then
    raise notice 'H2 PASS review removed, original kept in the audit log';
  else raise notice 'H2 FAIL'; end if;
exception when others then raise notice 'H2 FAIL [%] %', sqlstate, sqlerrm; end $$;

-- A reported message, put in place as the system would.
reset role;
insert into public.messages (id, request_id, sender_id, kind, body, reported_at, reported_reason)
values ('88888888-0000-4000-8000-000000000001', '66666666-0000-4000-8000-000000000003',
        '11111111-1111-4111-8111-000000000004', 'text', 'Pay me in cash and skip the app.',
        now(), 'Asked to pay off-platform');
select set_config('request.jwt.claims', :'admin', true);
set local role authenticated;

do $$ declare m public.messages; begin
  perform public.admin_review_message_report('88888888-0000-4000-8000-000000000001', true,
    'Off-platform payment request');
  select * into m from public.messages where id = '88888888-0000-4000-8000-000000000001';
  if m.kind = 'system' and m.body like '%removed by ReadyTech%' and m.report_reviewed_at is not null
     and exists (select 1 from public.admin_audit_log
                  where action = 'message.redact'
                    and detail -> 'original' ->> 'body' = 'Pay me in cash and skip the app.') then
    raise notice 'H3 PASS message redacted, original preserved for disputes';
  else raise notice 'H3 FAIL %', m; end if;
exception when others then raise notice 'H3 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ begin
  perform public.admin_review_message_report('88888888-0000-4000-8000-000000000001', false);
  raise notice 'H4 FAIL report reviewed twice';
exception when others then
  if sqlstate = 'RT409' then raise notice 'H4 PASS a report is reviewed once';
  else raise notice 'H4 FAIL [%] %', sqlstate, sqlerrm; end if;
end $$;

\echo ''
\echo '=== I. THE AUDIT LOG IS APPEND-ONLY, EVEN FOR ADMINISTRATORS ==='

do $$ declare n int; begin
  select count(*) into n from public.admin_audit_log;
  raise notice 'I1 % audit entries written by this suite', n;
end $$;

do $$ begin
  delete from public.admin_audit_log;
  raise notice 'I2 FAIL admin deleted the audit log';
exception when others then raise notice 'I2 PASS delete refused: %', sqlerrm; end $$;

do $$ begin
  update public.admin_audit_log set action = 'nothing.happened';
  raise notice 'I3 FAIL admin rewrote the audit log';
exception when others then raise notice 'I3 PASS update refused: %', sqlerrm; end $$;

do $$ begin
  update public.payments set status = 'refunded';
  raise notice 'I4 FAIL admin moved money from the console';
exception when others then raise notice 'I4 PASS payments stay read-only: %', sqlerrm; end $$;

rollback;
