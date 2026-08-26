-- ReadyTech :: identity
--
-- Account credentials live in auth.users and are owned by Supabase Auth.
-- Everything the marketplace shows about a person lives here. The split
-- matters: nothing in these tables is a secret, so they can be exposed through
-- PostgREST and constrained with row level security, while password material
-- and session state stay in a schema the client cannot reach at all.

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

comment on function public.set_updated_at is
  'Keeps updated_at honest. A client-supplied timestamp is not trustworthy.';

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  email extensions.citext not null,
  phone text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint profiles_full_name_length
    check (char_length(full_name) <= 120),
  -- Stored in E.164. Normalising on the way in means the same person cannot
  -- appear as +60123456789 and 0123456789.
  constraint profiles_phone_format
    check (phone is null or phone ~ '^\+[1-9][0-9]{7,14}$')
);

comment on table public.profiles is
  'Public identity. Never store secrets, tokens or payment identifiers here.';

create unique index profiles_email_key on public.profiles (email);
create index profiles_phone_idx on public.profiles (phone) where phone is not null;

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- user_roles
-- ---------------------------------------------------------------------------

-- Kept out of profiles on purpose. A user may update their own profile row;
-- if the role lived there, "update your name" and "make yourself an admin"
-- would be the same statement.
create table public.user_roles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  role public.user_role not null default 'customer',
  assigned_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.user_roles is
  'Authorisation source of truth. Writable only by admins and the sign-up trigger.';

create index user_roles_role_idx on public.user_roles (role);

create trigger user_roles_set_updated_at
  before update on public.user_roles
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Role lookups used by every policy
-- ---------------------------------------------------------------------------

-- SECURITY DEFINER so a policy can read user_roles without the caller needing
-- their own select permission on it, and STABLE so Postgres evaluates it once
-- per statement rather than once per row.
create or replace function public.current_user_role()
returns public.user_role
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select role from public.user_roles where user_id = auth.uid();
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.is_technician()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'technician'
  );
$$;

-- ---------------------------------------------------------------------------
-- Sign-up
-- ---------------------------------------------------------------------------

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  insert into public.profiles (id, full_name, email, phone)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    new.email,
    nullif(new.raw_user_meta_data ->> 'phone', '')
  )
  on conflict (id) do nothing;

  -- Everyone starts as a customer. Becoming a technician requires an admin to
  -- approve a verification; becoming an admin is a manual, deliberate act.
  -- Reading a role out of client-supplied metadata here would let anyone
  -- register as an administrator.
  insert into public.user_roles (user_id, role)
  values (new.id, 'customer')
  on conflict (user_id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user is
  'Creates the profile and default role in the same transaction as the account, '
  'so an account can never exist without a profile.';

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Keep the profile email in step when a user changes it through Supabase Auth.
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.email is distinct from old.email then
    update public.profiles set email = new.email where id = new.id;
  end if;
  return new;
end;
$$;

create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row execute function public.handle_user_email_change();
