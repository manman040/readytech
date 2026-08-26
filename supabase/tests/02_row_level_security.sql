\pset pager off
-- SET LOCAL only takes effect inside a transaction. Every block below is an
-- explicit BEGIN/ROLLBACK so the role and JWT claims actually apply and RLS is
-- genuinely exercised, rather than silently running as superuser.

\echo '=== F. ARRIVAL CODE GATES CHECK-IN (as the assigned technician) ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000002","role":"authenticated"}', true);
set local role authenticated;

select auth.uid() as acting_as;

do $$
begin
  update public.service_requests set status='ARRIVED' where reference='RT-26-000003';
  raise notice 'PASS: technician marked ARRIVED';
exception when others then
  raise notice 'FAIL: [%] %', sqlstate, sqlerrm;
end $$;

do $$
begin
  update public.service_requests set status='CHECKING_IN' where reference='RT-26-000003';
  raise notice 'FAIL: checked in with no verified code';
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;

do $$
begin
  perform public.verify_arrival_code(
    (select id from public.service_requests where reference='RT-26-000003'),
    '0000');
  raise notice 'FAIL: wrong code accepted';
exception when others then
  raise notice 'PASS (wrong code): [%] %', sqlstate, sqlerrm;
end $$;

do $$
declare code text;
begin
  select arrival_code into code from public.service_requests where reference='RT-26-000003';
  perform public.verify_arrival_code(
    (select id from public.service_requests where reference='RT-26-000003'), code);
  raise notice 'PASS (correct code): status is now %',
    (select status from public.service_requests where reference='RT-26-000003');
exception when others then
  raise notice 'FAIL: [%] %', sqlstate, sqlerrm;
end $$;
rollback;

\echo ''
\echo '=== H. RLS AS CUSTOMER Adam (owns RT-26-000001 only) ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000001","role":"authenticated"}', true);
set local role authenticated;
select
  (select count(*) from public.service_requests)  as requests_visible,
  (select count(*) from public.devices)           as devices_visible,
  (select count(*) from public.saved_addresses)   as addresses_visible,
  (select count(*) from public.payments)          as payments_visible,
  (select count(*) from public.technician_earnings) as earnings_visible,
  (select count(*) from public.messages)          as messages_visible;
rollback;

\echo ''
\echo '=== I. RLS AS TECHNICIAN Ahmad (holds RT-26-000001 only) ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000001","role":"authenticated"}', true);
set local role authenticated;
select
  (select count(*) from public.service_requests)  as requests_visible,
  (select count(*) from public.saved_addresses)   as customer_addresses_visible,
  (select count(*) from public.devices)           as devices_visible,
  (select count(*) from public.technician_earnings) as own_earnings_visible;
rollback;

\echo ''
\echo '=== J. TECHNICIAN CANNOT EDIT REPUTATION OR VERIFICATION ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  update public.technician_profiles
     set rating_average = 5.0, rating_count = 999
   where id = '22222222-2222-4222-8222-000000000001';
  raise notice 'FAIL: technician edited their own rating';
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;
do $$
begin
  update public.technician_profiles set verification_status = 'approved'
   where id = '22222222-2222-4222-8222-000000000009';
  if found then raise notice 'FAIL: verified another technician';
  else raise notice 'PASS: no row updated - policy hid it'; end if;
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;
-- Availability is theirs to change.
do $$
begin
  update public.technician_profiles set is_available = false
   where id = '22222222-2222-4222-8222-000000000001';
  raise notice 'PASS: technician may still set their own availability';
exception when others then
  raise notice 'FAIL: [%] %', sqlstate, sqlerrm;
end $$;
rollback;

\echo ''
\echo '=== K. CUSTOMER CANNOT PROMOTE THEMSELVES ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  update public.user_roles set role='admin'
   where user_id='11111111-1111-4111-8111-000000000001';
  if found then raise notice 'FAIL: customer became an admin';
  else raise notice 'PASS: no row updated - policy refused the write'; end if;
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;
select role as role_after_attempt from public.user_roles
 where user_id='11111111-1111-4111-8111-000000000001';
rollback;

\echo ''
\echo '=== L. CUSTOMER CANNOT WRITE PAYMENTS OR EARNINGS ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000001","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  insert into public.payments (request_id, amount_sen, status, paid_at, verified_at)
  values ('66666666-0000-4000-8000-000000000001', 1, 'paid', now(), now());
  raise notice 'FAIL: customer inserted a settled payment';
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;
rollback;

\echo ''
\echo '=== M. CUSTOMER CANNOT REASSIGN THEIR OWN JOB ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000004","role":"authenticated"}', true);
set local role authenticated;
do $$
begin
  update public.service_requests
     set assigned_technician_id = '22222222-2222-4222-8222-000000000001'
   where reference = 'RT-26-000003';
  raise notice 'FAIL: customer reassigned the technician';
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;
do $$
begin
  update public.service_requests set estimated_total_max_sen = 1
   where reference = 'RT-26-000003';
  raise notice 'FAIL: customer rewrote the estimate';
exception when others then
  raise notice 'PASS: [%] %', sqlstate, sqlerrm;
end $$;
rollback;

\echo ''
\echo '=== N. TECHNICIAN OFFER FEED IS REDACTED ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-4222-8222-000000000007","role":"authenticated"}', true);
set local role authenticated;
-- Aisyah has an open offer on RT-26-000004 but does not hold the job.
select count(*) as full_rows_visible_on_service_requests
  from public.service_requests where reference='RT-26-000004';
select reference, urgency, distance_km,
       approximate_latitude, approximate_longitude
  from public.technician_open_offers();
rollback;

\echo ''
\echo '=== O. AN UNRELATED USER SEES NOTHING ==='
begin;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-4111-8111-000000000006","role":"authenticated"}', true);
set local role authenticated;
select
  (select count(*) from public.service_requests) as requests_visible,
  (select count(*) from public.devices)          as devices_visible,
  (select count(*) from public.messages)         as messages_visible,
  (select count(*) from public.payments)         as payments_visible;
rollback;
