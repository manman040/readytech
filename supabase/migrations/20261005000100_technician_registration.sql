-- ReadyTech :: technician self-registration
--
-- Until now every account started as a customer, and the only way to become a
-- technician was an administrator editing user_roles by hand. That is the right
-- default for a seed, but it is not a product: a technician has to be able to
-- register from the app and wait to be verified, the same way a driver joins a
-- ride-hailing platform.
--
-- Reading the *technician* role out of sign-up metadata is safe because the
-- role on its own grants nothing a customer does not already have. Everything
-- that matters keys on an approved verification, not on the role:
--
--   - technician_is_matchable() refuses an unverified technician, so matching
--     never offers them a job, and without a job every job-scoped policy
--     (customer profiles, devices, addresses, messages) returns nothing;
--   - profiles_select_verified_technicians hides them from customers;
--   - the only policy that tests is_technician() lets a technician insert
--     their own technician_profiles row, which this trigger now does for them.
--
-- Verification stays an administrative act, through technician_verifications
-- and the column guard on technician_profiles.
--
-- The administrator role is different in kind and is still never read from
-- metadata. Anything other than 'technician' falls through to 'customer'.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  requested_role text := new.raw_user_meta_data ->> 'role';
  assigned_role public.user_role := 'customer';
begin
  if requested_role = 'technician' then
    assigned_role := 'technician';
  end if;

  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do nothing;

  insert into public.user_roles (user_id, role)
  values (new.id, assigned_role)
  on conflict (user_id) do nothing;

  -- The technician's extended profile is created here, in the same
  -- transaction as the account, for the same reason the base profile is: with
  -- email confirmation on there is no session after sign-up, so the client
  -- could not create it, and a technician with no technician_profiles row
  -- would be invisible to every later phase. It starts unsubmitted and
  -- unavailable; the defaults on the table say so.
  if assigned_role = 'technician' then
    insert into public.technician_profiles (id)
    values (new.id)
    on conflict (id) do nothing;
  end if;

  return new;
end;
$$;

comment on function public.handle_new_user is
  'Creates the profile, the role and - for a technician registration - the '
  'technician profile in the same transaction as the account. Only '
  '''technician'' is honoured from sign-up metadata; everything else, '
  'including ''admin'', becomes a customer.';

comment on table public.user_roles is
  'Authorisation source of truth. Writable only by admins and the sign-up '
  'trigger, which assigns customer or - when asked - unverified technician.';
