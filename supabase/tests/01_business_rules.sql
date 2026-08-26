\set ON_ERROR_STOP off
\pset pager off

\echo '=== 1. SEED ROW COUNTS ==='
select 'profiles' as t, count(*) from public.profiles
union all select 'user_roles(technician)', count(*) from public.user_roles where role = 'technician'
union all select 'user_roles(admin)', count(*) from public.user_roles where role = 'admin'
union all select 'technician_profiles', count(*) from public.technician_profiles
union all select 'service_categories', count(*) from public.service_categories
union all select 'devices', count(*) from public.devices
union all select 'service_requests', count(*) from public.service_requests
union all select 'quotations', count(*) from public.quotations
union all select 'payments', count(*) from public.payments
union all select 'warranties', count(*) from public.warranties
union all select 'reviews', count(*) from public.reviews
union all select 'status_history(auto)', count(*) from public.service_status_history
order by 1;

\echo ''
\echo '=== 2. POSTGIS GENERATED COLUMNS POPULATED ==='
select count(*) as requests_with_geography from public.service_requests where service_location is not null;
select count(*) as technicians_with_base_geo from public.technician_profiles where base_location is not null;
select round((extensions.st_distance(
         (select service_location from public.service_requests where reference='RT-26-000003'),
         (select location from public.technician_locations where technician_id='22222222-2222-4222-8222-000000000002')
       )/1000)::numeric,2) as km_technician_to_job;

\echo ''
\echo '=== 3. QUOTATION TOTALS COMPUTED BY TRIGGER ==='
select q.version, q.kind, q.status, q.subtotal_sen, q.platform_fee_sen, q.total_sen
from public.quotations q
join public.service_requests r on r.id = q.request_id
where r.reference = 'RT-26-000001';

\echo ''
\echo '=== 4. RLS ENABLED ON EVERY PUBLIC TABLE ==='
select count(*) filter (where rowsecurity) as rls_on,
       count(*) filter (where not rowsecurity) as rls_off
from pg_tables where schemaname = 'public';
select tablename from pg_tables
where schemaname='public' and not rowsecurity order by 1;

\echo ''
\echo '=== 5. POLICY COUNT ==='
select count(*) as policies from pg_policies where schemaname='public';

\echo ''
\echo '=== 6. STATE MACHINE: illegal transition must be REJECTED ==='
-- REQUESTED -> PAID is not in the transition table.
do $$
begin
  update public.service_requests set status='PAID' where reference='RT-26-000004';
  raise notice 'FAIL: illegal transition was allowed';
exception when others then
  raise notice 'PASS: rejected [%] %', sqlstate, sqlerrm;
end $$;

\echo ''
\echo '=== 7. STATE MACHINE: PAID requires a verified payment ==='
do $$
begin
  update public.service_requests set status='PAYMENT_PENDING' where reference='RT-26-000002';
  raise notice 'FAIL: skipped straight to payment';
exception when others then
  raise notice 'PASS: rejected [%] %', sqlstate, sqlerrm;
end $$;

\echo ''
\echo '=== 8. APPROVED QUOTATION IS IMMUTABLE ==='
do $$
declare qid uuid;
begin
  select id into qid from public.quotations where status='approved' limit 1;
  update public.quotations set total_sen = total_sen + 5000 where id = qid;
  raise notice 'FAIL: approved quotation was edited';
exception when others then
  raise notice 'PASS: rejected [%] %', sqlstate, sqlerrm;
end $$;

\echo ''
\echo '=== 9. DOUBLE BOOKING: one active job per customer ==='
do $$
begin
  insert into public.service_requests
    (customer_id, problem_description, service_latitude, service_longitude, service_address)
  values ('11111111-1111-4111-8111-000000000004',
          'Second concurrent request that must be refused.',
          3.1304, 101.6709, 'Unit 5-3, Menara Bangsar');
  raise notice 'FAIL: customer got two active jobs';
exception when others then
  raise notice 'PASS: rejected [%] %', sqlstate, sqlerrm;
end $$;

\echo ''
\echo '=== 10. EARNINGS ARITHMETIC CONSTRAINT ==='
do $$
begin
  update public.technician_earnings set commission_sen = 1 where net_sen > 0;
  raise notice 'FAIL: statement no longer balances';
exception when others then
  raise notice 'PASS: rejected [%] %', sqlstate, sqlerrm;
end $$;

\echo ''
\echo '=== 11. ARRIVAL CODE + REFERENCE GENERATED ==='
select reference, arrival_code, status from public.service_requests order by reference;

\echo ''
\echo '=== 12. TECHNICIAN RATING REFRESHED BY TRIGGER ==='
select p.full_name, t.rating_average, t.rating_count
from public.technician_profiles t join public.profiles p on p.id=t.id
where t.id='22222222-2222-4222-8222-000000000001';

\echo ''
\echo '=== 13. ESTIMATE FUNCTION ==='
select * from public.estimate_service_cost(
  '44444444-0000-4000-8000-000000000001', 'normal', 5.0);

\echo ''
\echo '=== 14. MATCHING RANKS TECHNICIANS ==='
select full_name, distance_km, eta_minutes, specialisation, score
from public.rank_technicians(
  (select id from public.service_requests where reference='RT-26-000004'), 40, 5);

\echo ''
\echo '=== 15. STORAGE BUCKETS (all private) ==='
select id, public, file_size_limit from storage.buckets order by id;
