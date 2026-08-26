-- ReadyTech :: service catalogue and pricing
--
-- Prices are never written into the mobile app. Everything a quotation or an
-- estimate is built from lives here, so an administrator can change a fee
-- without shipping a release, and so a historical receipt can be explained by
-- the configuration that was in force when it was issued.

-- ---------------------------------------------------------------------------
-- service_categories
-- ---------------------------------------------------------------------------

create table public.service_categories (
  id uuid primary key default extensions.gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  icon text,
  -- Which kinds of device this category can apply to, used to narrow the
  -- follow-up questions after classification.
  device_types public.device_type[] not null default '{}',

  -- Money is always a whole number of sen. See docs/ARCHITECTURE.md.
  diagnosis_fee_sen bigint not null default 2000,
  estimated_repair_min_sen bigint not null default 0,
  estimated_repair_max_sen bigint not null default 0,
  default_warranty_days integer not null default 7,

  requires_specialist boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint service_categories_fees_non_negative
    check (
      diagnosis_fee_sen >= 0
      and estimated_repair_min_sen >= 0
      and estimated_repair_max_sen >= 0
    ),
  constraint service_categories_estimate_ordered
    check (estimated_repair_max_sen >= estimated_repair_min_sen),
  constraint service_categories_warranty_sane
    check (default_warranty_days between 0 and 365)
);

create index service_categories_active_idx
  on public.service_categories (is_active, sort_order)
  where is_active;

create trigger service_categories_set_updated_at
  before update on public.service_categories
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- pricing_config
-- ---------------------------------------------------------------------------

create table public.pricing_config (
  key text primary key,
  value jsonb not null,
  description text not null,
  updated_by uuid references public.profiles (id) on delete set null,
  updated_at timestamptz not null default now()
);

comment on table public.pricing_config is
  'Marketplace-wide pricing knobs. Read by Edge Functions when building an '
  'estimate or a quotation; never read directly by the mobile client for '
  'anything it then sends back as a price.';

create trigger pricing_config_set_updated_at
  before update on public.pricing_config
  for each row execute function public.set_updated_at();

-- Typed accessors, so a caller cannot silently get a JSON null where it wanted
-- a number.
create or replace function public.pricing_int(config_key text)
returns bigint
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (value #>> '{}')::bigint from public.pricing_config where key = config_key;
$$;

create or replace function public.pricing_numeric(config_key text)
returns numeric
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select (value #>> '{}')::numeric from public.pricing_config where key = config_key;
$$;

insert into public.pricing_config (key, value, description) values
  ('diagnosis_fee_sen', '2000',
   'Default on-site diagnosis fee in sen, when the category does not override it.'),
  ('travel_base_fee_sen', '500',
   'Flat call-out fee in sen, charged regardless of distance.'),
  ('travel_per_km_sen', '100',
   'Additional travel fee in sen for each kilometre of the technician journey.'),
  ('travel_fee_cap_sen', '3000',
   'Upper bound on the travel component, so a distant match cannot produce a '
   'surprising number.'),
  ('priority_surcharge_sen', '1000',
   'Added for a priority request.'),
  ('emergency_surcharge_sen', '3000',
   'Added for an emergency request.'),
  ('platform_fee_sen', '500',
   'Fixed platform fee added to the customer total.'),
  ('commission_percent', '10.0',
   'Share of the quotation subtotal retained by ReadyTech, as a percentage.'),
  ('default_warranty_days', '7',
   'Warranty length used when the category does not specify one.'),
  ('matching_radius_km', '15',
   'Initial search radius for technician matching.'),
  ('matching_radius_max_km', '40',
   'Radius the search may expand to when nobody nearby accepts.'),
  ('offer_timeout_seconds', '45',
   'How long a technician has to accept an auto-match offer before it moves on.'),
  ('matching_weights',
   '{"specialisation": 40, "distance": 20, "availability": 15, "rating": 10, "response_rate": 5, "completion_rate": 5, "eta": 5}',
   'Relative weights of the technician ranking factors. Kept server side; the '
   'exact score is never shown to customers or technicians.'),
  ('cancellation_free_window_seconds', '120',
   'Grace period after a technician accepts, during which a customer may cancel '
   'with no fee.'),
  ('cancellation_fee_sen', '1000',
   'Charged when a customer cancels after the grace period and the technician '
   'is already travelling.');
