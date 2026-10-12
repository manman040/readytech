\pset pager off
-- Technician self-registration, checked the way it happens in production: a
-- row lands in auth.users carrying the sign-up metadata and the trigger does
-- the rest. Then the new technician acts as themselves, so the policies and
-- column guard are genuinely exercised. Everything here is rolled back.

\echo '=== A. SIGN-UP TRIGGER HONOURS ONLY THE TECHNICIAN ROLE ==='
begin;

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, created_at, updated_at,
  raw_app_meta_data, raw_user_meta_data,
  confirmation_token, recovery_token, email_change_token_new, email_change
) values
  ('00000000-0000-0000-0000-000000000000', '77777777-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'reg-technician@readytech.test',
   extensions.crypt('ReadyTech123!', extensions.gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Reg Technician","phone":"+60123456999","role":"technician"}'::jsonb,
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '77777777-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'reg-wouldbe-admin@readytech.test',
   extensions.crypt('ReadyTech123!', extensions.gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Reg Admin Wannabe","role":"admin"}'::jsonb,
   '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', '77777777-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'reg-customer@readytech.test',
   extensions.crypt('ReadyTech123!', extensions.gen_salt('bf')), now(), now(), now(),
   '{"provider":"email","providers":["email"]}'::jsonb,
   '{"full_name":"Reg Customer"}'::jsonb,
   '', '', '', '');

select p.email,
       r.role,
       t.verification_status,
       t.is_available,
       case
         when p.email like 'reg-technician%'
              and r.role = 'technician'
              and t.verification_status = 'unsubmitted'
              and not t.is_available then 'PASS'
         when p.email like 'reg-wouldbe-admin%' and r.role = 'customer' and t.id is null then 'PASS'
         when p.email like 'reg-customer%'      and r.role = 'customer' and t.id is null then 'PASS'
         else 'FAIL'
       end as result
from public.profiles p
join public.user_roles r on r.user_id = p.id
left join public.technician_profiles t on t.id = p.id
where p.id::text like '77777777-%'
order by p.email;

\echo ''
\echo '=== B. THE NEW TECHNICIAN, ACTING AS THEMSELVES ==='
select set_config('request.jwt.claims',
  '{"sub":"77777777-0000-4000-8000-000000000001","role":"authenticated"}', true);
set local role authenticated;

select auth.uid() as acting_as, public.current_user_role() as role_seen_by_policies;

select count(*) as own_technician_profile_rows_expect_1
from public.technician_profiles where id = auth.uid();

do $$ declare n int; begin
  update public.technician_profiles
     set headline = 'Laptop repairs', years_experience = 4, service_radius_km = 20
   where id = auth.uid();
  get diagnostics n = row_count;
  if n = 1 then raise notice 'PASS: technician completed their own profile';
  else raise notice 'FAIL: % rows affected editing own profile (policy hid the row?)', n;
  end if;
exception when others then
  raise notice 'FAIL: [%] %', sqlstate, sqlerrm;
end $$;

do $$
begin
  update public.technician_profiles set verification_status = 'approved' where id = auth.uid();
  raise notice 'FAIL: technician approved themselves';
exception when others then
  raise notice 'PASS (self-approval refused): [%] %', sqlstate, sqlerrm;
end $$;

do $$
begin
  update public.technician_profiles set is_available = true where id = auth.uid();
  if public.technician_is_matchable(auth.uid()) then
    raise notice 'FAIL: unverified technician is matchable';
  else
    raise notice 'PASS: available but unverified, so never offered work';
  end if;
exception when others then
  raise notice 'FAIL: [%] %', sqlstate, sqlerrm;
end $$;

-- Holding no job, the new technician sees no customer at all. (Approved
-- technicians' public identities are visible to every signed-in user, so they
-- are excluded from the count.)
select count(*) as customer_profiles_visible_expect_0
from public.profiles p
where p.id <> auth.uid()
  and not exists (select 1 from public.technician_profiles t where t.id = p.id);

rollback;
