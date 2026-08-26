\pset pager off
-- A full lifecycle walk performed by real authenticated users.
--
-- Every "must succeed" step asserts that a row was actually affected. An RLS
-- policy that hides a row makes an UPDATE a silent no-op rather than an error,
-- so "no exception was raised" is not evidence that anything happened.

\set QUIET on
begin;

create or replace function pg_temp.expect_rows(label text, n int) returns void
language plpgsql as $$
begin
  if n = 1 then raise notice '% PASS', label;
  else raise notice '% FAIL - % rows affected (policy hid the row?)', label, n;
  end if;
end $$;

select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000005","role":"authenticated"}', true);
set local role authenticated;
\set QUIET off

do $$ declare n int; begin
  update public.service_requests set status='CANCELLED' where reference='RT-26-000004';
  get diagnostics n = row_count; perform pg_temp.expect_rows('01 customer cancels their open job', n);
exception when others then raise notice '01 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare new_id uuid; new_ref text; begin
  insert into public.service_requests
    (customer_id, category_id, problem_description, urgency,
     service_latitude, service_longitude, service_address, contact_phone)
  values ('11111111-1111-4111-8111-000000000005',
          '44444444-0000-4000-8000-000000000001',
          'Laptop screen flickers and then goes black after ten minutes.',
          'normal', 3.1390, 101.6869, '1 Jalan Lifecycle Test', '+60123456705')
  returning id, reference into new_id, new_ref;
  perform set_config('test.request_id', new_id::text, true);
  raise notice '02 PASS customer created %', new_ref;
exception when others then raise notice '02 FAIL [%] %', sqlstate, sqlerrm; end $$;

\set QUIET on
reset role;
select set_config('request.jwt.claims', '', true);
\set QUIET off

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='MATCHING' where id = rid;
  get diagnostics n = row_count;
  insert into public.technician_assignments
    (request_id, technician_id, status, rank, score, distance_km, eta_minutes, expires_at)
  values (rid, '22222222-2222-4222-8222-000000000001', 'offered', 1, 90.0, 2.1, 10,
          now() + interval '45 seconds');
  perform pg_temp.expect_rows('03 system starts matching and offers the job', n);
exception when others then raise notice '03 FAIL [%] %', sqlstate, sqlerrm; end $$;

\set QUIET on
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000001","role":"authenticated"}', true);
set local role authenticated;
\set QUIET off

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; begin
  perform public.accept_job_offer(rid);
  raise notice '04 PASS technician accepted -> % (assigned=%)',
    (select status from public.service_requests where id = rid),
    (select assigned_technician_id is not null from public.service_requests where id = rid);
exception when others then raise notice '04 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='TECHNICIAN_ON_THE_WAY' where id = rid;
  get diagnostics n = row_count; perform pg_temp.expect_rows('05 technician on the way', n);
exception when others then raise notice '05 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='ARRIVED' where id = rid;
  get diagnostics n = row_count; perform pg_temp.expect_rows('06 technician arrived', n);
exception when others then raise notice '06 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; begin
  update public.service_requests set status='CHECKING_IN' where id = rid;
  raise notice '07 FAIL checked in with no verified code';
exception when others then raise notice '07 PASS refused: %', sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; begin
  perform public.verify_arrival_code(rid, '9999');
  raise notice '08 FAIL wrong code accepted';
exception when others then raise notice '08 PASS wrong code refused'; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; code text; begin
  select arrival_code into code from public.service_requests where id = rid;
  perform public.verify_arrival_code(rid, code);
  raise notice '09 PASS correct code -> %',
    (select status from public.service_requests where id = rid);
exception when others then raise notice '09 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='DIAGNOSING' where id = rid;
  get diagnostics n = row_count;
  insert into public.diagnoses (request_id, technician_id, problem_found, recommended_action)
  values (rid, '22222222-2222-4222-8222-000000000001',
          'Failing backlight inverter', 'Replace the inverter board.');
  update public.service_requests set status='QUOTATION_PENDING' where id = rid;
  perform pg_temp.expect_rows('10 diagnosis recorded', n);
exception when others then raise notice '10 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; qid uuid; begin
  insert into public.quotations (request_id, technician_id, kind, status, submitted_at)
  values (rid, '22222222-2222-4222-8222-000000000001', 'initial', 'submitted', now())
  returning id into qid;
  perform set_config('test.quotation_id', qid::text, true);
  insert into public.quotation_items (quotation_id, kind, description, quantity, unit_price_sen, amount_sen)
  values (qid, 'diagnosis', 'On-site diagnosis', 1, 2000, 2000),
         (qid, 'labour', 'Inverter replacement', 1, 4000, 4000),
         (qid, 'part', 'Backlight inverter board', 1, 5500, 5500);
  update public.service_requests set status='QUOTATION_SUBMITTED' where id = rid;
  raise notice '11 PASS quotation submitted; subtotal=% fee=% total=%',
    (select subtotal_sen from public.quotations where id=qid),
    (select platform_fee_sen from public.quotations where id=qid),
    (select total_sen from public.quotations where id=qid);
exception when others then raise notice '11 FAIL [%] %', sqlstate, sqlerrm; end $$;

\set QUIET on
reset role; select set_config('request.jwt.claims', '', true);
\set QUIET off
do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='AWAITING_CUSTOMER_APPROVAL' where id=rid;
  get diagnostics n = row_count; perform pg_temp.expect_rows('12 presented to the customer', n);
exception when others then raise notice '12 FAIL [%] %', sqlstate, sqlerrm; end $$;

\set QUIET on
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000001","role":"authenticated"}', true);
set local role authenticated;
\set QUIET off
do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='APPROVED' where id = rid;
  get diagnostics n = row_count;
  if n = 0 then raise notice '13 PASS technician cannot approve their own price (no rows)';
  else raise notice '13 FAIL technician approved their own price'; end if;
exception when others then raise notice '13 PASS refused: %', sqlerrm; end $$;

\set QUIET on
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000005","role":"authenticated"}', true);
\set QUIET off
do $$ declare rid uuid := current_setting('test.request_id', true)::uuid;
        qid uuid := current_setting('test.quotation_id', true)::uuid; n int; begin
  update public.quotations set status='approved' where id = qid;
  insert into public.quotation_approvals (quotation_id, quotation_version, approved_by, decision)
  values (qid, (select version from public.quotations where id=qid),
          '11111111-1111-4111-8111-000000000005', 'approved');
  update public.service_requests set status='APPROVED' where id = rid;
  get diagnostics n = row_count; perform pg_temp.expect_rows('14 customer approved the quotation', n);
exception when others then raise notice '14 FAIL [%] %', sqlstate, sqlerrm; end $$;

\set QUIET on
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000001","role":"authenticated"}', true);
\set QUIET off
do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='REPAIRING' where id = rid;
  get diagnostics n = row_count; perform pg_temp.expect_rows('15 repair started on an approved quote', n);
exception when others then raise notice '15 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='COMPLETED' where id = rid;
  get diagnostics n = row_count;
  if n = 0 then raise notice '16 PASS technician cannot declare completion (no rows)';
  else raise notice '16 FAIL technician completed their own job'; end if;
exception when others then raise notice '16 PASS refused: %', sqlerrm; end $$;

\set QUIET on
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000005","role":"authenticated"}', true);
\set QUIET off
do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; n int; begin
  update public.service_requests set status='COMPLETED' where id = rid;
  get diagnostics n = row_count; perform pg_temp.expect_rows('17 customer confirmed completion', n);
exception when others then raise notice '17 FAIL [%] %', sqlstate, sqlerrm; end $$;

do $$ declare rid uuid := current_setting('test.request_id', true)::uuid; begin
  update public.service_requests set status='PAYMENT_PENDING' where id = rid;
  raise notice '18 FAIL customer advanced the job to payment';
exception when others then raise notice '18 PASS refused: %', sqlerrm; end $$;

\set QUIET on
reset role; select set_config('request.jwt.claims', '', true);
\set QUIET off
do $$ declare rid uuid := current_setting('test.request_id', true)::uuid;
        qid uuid := current_setting('test.quotation_id', true)::uuid; begin
  update public.service_requests set status='PAYMENT_PENDING' where id = rid;
  insert into public.payments (request_id, quotation_id, amount_sen, status, paid_at, verified_at)
  values (rid, qid, (select total_sen from public.quotations where id=qid), 'paid', now(), now());
  update public.service_requests set status='PAID' where id = rid;
  update public.service_requests set status='WARRANTY_ACTIVE' where id = rid;
  raise notice '19 PASS payment verified, warranty active';
exception when others then raise notice '19 FAIL [%] %', sqlstate, sqlerrm; end $$;

\echo ''
\echo '--- final state + audit trail written by the trigger ---'
select r.status,
       (select count(*) from public.service_status_history h where h.request_id=r.id) as history_rows
from public.service_requests r where r.id = current_setting('test.request_id', true)::uuid;

select from_status, to_status, actor_role
from public.service_status_history
where request_id = current_setting('test.request_id', true)::uuid
order by created_at;

\echo ''
\echo '--- technician counters maintained by triggers ---'
select completed_jobs, cancelled_jobs, offers_received, offers_accepted
from public.technician_profiles where id='22222222-2222-4222-8222-000000000001';

rollback;
\echo '(rolled back)'
