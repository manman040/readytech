-- ReadyTech :: customer devices and saved addresses

create table public.devices (
  id uuid primary key default extensions.gen_random_uuid(),
  owner_id uuid not null references public.profiles (id) on delete cascade,

  device_type public.device_type not null,
  nickname text not null,
  brand text,
  model text,
  serial_number text,
  purchase_date date,
  notes text,

  -- Devices are archived, never deleted, because completed services reference
  -- them and a service history that loses its subject is not a history.
  archived_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint devices_nickname_length
    check (char_length(nickname) between 1 and 80),
  constraint devices_purchase_date_not_future
    check (purchase_date is null or purchase_date <= current_date)
);

create index devices_owner_idx
  on public.devices (owner_id, created_at desc)
  where archived_at is null;

create trigger devices_set_updated_at
  before update on public.devices
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- saved_addresses
-- ---------------------------------------------------------------------------

create table public.saved_addresses (
  id uuid primary key default extensions.gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,

  label public.address_label not null default 'home',
  name text not null default '',
  address_line text not null,
  city text,
  state text,
  postcode text,

  latitude numeric(9, 6) not null,
  longitude numeric(9, 6) not null,
  location extensions.geography(Point, 4326)
    generated always as (
      extensions.st_setsrid(
        extensions.st_makepoint(longitude::float8, latitude::float8),
        4326
      )::extensions.geography
    ) stored,

  -- Free-text help for the technician: gate code, floor, which shop unit.
  directions text,
  is_default boolean not null default false,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint saved_addresses_latitude_range check (latitude between -90 and 90),
  constraint saved_addresses_longitude_range
    check (longitude between -180 and 180),
  constraint saved_addresses_postcode_format
    check (postcode is null or postcode ~ '^[0-9]{5}$')
);

create index saved_addresses_user_idx on public.saved_addresses (user_id);

-- At most one default per user, enforced by the index rather than by hoping
-- every write path remembers to clear the previous one.
create unique index saved_addresses_single_default_idx
  on public.saved_addresses (user_id)
  where is_default;

create trigger saved_addresses_set_updated_at
  before update on public.saved_addresses
  for each row execute function public.set_updated_at();

-- Promoting an address to default demotes the previous one, so the unique
-- index above never has to reject an otherwise reasonable update.
create or replace function public.demote_other_default_addresses()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.is_default then
    update public.saved_addresses
       set is_default = false
     where user_id = new.user_id
       and id <> new.id
       and is_default;
  end if;
  return new;
end;
$$;

create trigger saved_addresses_single_default
  before insert or update of is_default on public.saved_addresses
  for each row when (new.is_default)
  execute function public.demote_other_default_addresses();
