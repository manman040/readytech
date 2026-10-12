-- ReadyTech :: appoint an administrator from the database
--
-- An administrator is appointed, never self-declared: handle_new_user() refuses
-- 'admin' from sign-up metadata, and admin_set_user_role() can only be called by
-- an existing administrator. That leaves a bootstrapping problem - the first
-- administrator of a new environment, or recovery when nobody who can sign in
-- to the console is an administrator - and this script is the answer to it.
-- Otherwise, administrators appoint each other from the console
-- (Accounts → Change role), which is the path to prefer.
--
-- 1. The person signs up normally - in the app - and confirms their email.
--    That gives them a real account with their own password.
-- 2. Someone with database access runs this, naming that email:
--
--    Local:
--      docker exec -i supabase_db_readytech psql -U postgres -d postgres \
--        -v email=person@example.com < supabase/snippets/appoint_first_admin.sql
--
--    Hosted: paste into the SQL editor and replace :'email' below with the
--    address in single quotes.
--
-- 3. They sign in to the admin console with the same email and password.
--
-- This grants nothing the operator does not already have - anyone who can run
-- it holds the database. What it adds is that the act is deliberate and
-- recorded: it writes the same audit entry a console role change does, with no
-- admin_id because no administrator performed it.

\set ON_ERROR_STOP on

select set_config('readytech.appoint_email', :'email', false);

do $$
declare
  wanted text := current_setting('readytech.appoint_email');
  target uuid;
  previous public.user_role;
begin
  select p.id into target
    from public.profiles p
    join auth.users u on u.id = p.id
   where p.email = wanted
     and u.email_confirmed_at is not null;

  if target is null then
    raise exception 'No confirmed account for %. Sign up in the app and confirm the email first.', wanted;
  end if;

  select role into previous from public.user_roles where user_id = target;

  if previous = 'admin' then
    raise notice '% is already an administrator. Nothing changed.', wanted;
    return;
  end if;

  -- A technician holding a live job would leave that job in limbo; the console
  -- function refuses the same thing.
  if previous = 'technician' and exists (
    select 1 from public.service_requests r
     where r.assigned_technician_id = target
       and r.status not in ('COMPLETED', 'PAID', 'WARRANTY_ACTIVE', 'CANCELLED', 'DISPUTED')
  ) then
    raise exception 'That account is a technician holding a live job. Reassign or cancel it first.';
  end if;

  update public.user_roles set role = 'admin', assigned_by = null where user_id = target;

  insert into public.admin_audit_log (admin_id, action, target_table, target_id, detail)
  values (null, 'user.role.bootstrap', 'user_roles', target::text,
          jsonb_build_object('from', previous, 'to', 'admin',
                             'reason', 'Administrator appointed directly in the database'));

  raise notice 'Appointed % as an administrator (was %). They can sign in to the console now.', wanted, previous;
end;
$$;
