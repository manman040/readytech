-- ReadyTech :: payments and earnings
--
-- No client is ever trusted with a payment outcome. A row reaches
-- status = 'paid' only through the verify-payment Edge Function, which calls
-- ToyyibPay itself and writes with the service role. Row level security gives
-- customers and technicians read access and no write access at all.

create table public.payments (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete restrict,
  quotation_id uuid references public.quotations (id) on delete set null,

  provider public.payment_provider not null default 'toyyibpay',
  -- ToyyibPay's identifiers for the bill and the settled transaction.
  provider_bill_code text,
  provider_reference text,

  status public.payment_status not null default 'pending',
  amount_sen bigint not null,
  currency text not null default 'MYR',

  paid_at timestamptz,
  -- When *we* confirmed it against the provider, which is the timestamp that
  -- actually authorises release. A provider callback alone is a claim.
  verified_at timestamptz,
  failure_reason text,

  -- The provider's response, kept for reconciliation and disputes.
  provider_payload jsonb,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint payments_amount_positive check (amount_sen > 0),
  constraint payments_currency_supported check (currency = 'MYR'),
  constraint payments_paid_requires_verification
    check (status <> 'paid' or (paid_at is not null and verified_at is not null))
);

comment on constraint payments_paid_requires_verification on public.payments is
  'A payment cannot be marked paid without a server-side verification '
  'timestamp. This is the database refusing to take a client''s word for it.';

-- One settled payment per request. A retry after a failure is allowed; two
-- successful charges for the same job are not.
create unique index payments_single_settled_idx
  on public.payments (request_id)
  where status in ('paid', 'refunded', 'partially_refunded');

create index payments_request_idx
  on public.payments (request_id, created_at desc);

create index payments_bill_code_idx
  on public.payments (provider_bill_code)
  where provider_bill_code is not null;

create index payments_pending_idx
  on public.payments (status, created_at)
  where status in ('pending', 'awaiting_payment');

create trigger payments_set_updated_at
  before update on public.payments
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- payment_items
-- ---------------------------------------------------------------------------

-- A frozen copy of the breakdown at the moment of charge. Quotation rows can
-- be superseded by later work; a receipt has to keep saying what it said.
create table public.payment_items (
  id uuid primary key default extensions.gen_random_uuid(),
  payment_id uuid not null references public.payments (id) on delete cascade,
  kind public.quotation_item_kind not null,
  label text not null,
  amount_sen bigint not null,
  sort_order integer not null default 0,

  constraint payment_items_amount_non_negative check (amount_sen >= 0)
);

create index payment_items_payment_idx
  on public.payment_items (payment_id, sort_order);

-- ---------------------------------------------------------------------------
-- technician_earnings
-- ---------------------------------------------------------------------------

create table public.technician_earnings (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete restrict,
  technician_id uuid not null
    references public.technician_profiles (id) on delete restrict,
  payment_id uuid not null references public.payments (id) on delete restrict,

  gross_sen bigint not null,
  -- The rate in force when this job settled, copied rather than referenced.
  -- Changing the marketplace commission must not rewrite what a technician was
  -- already paid.
  commission_percent numeric(5, 2) not null,
  commission_sen bigint not null,
  net_sen bigint not null,

  status public.earning_status not null default 'pending',
  released_at timestamptz,
  withheld_reason text,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (request_id),
  constraint technician_earnings_amounts_non_negative
    check (gross_sen >= 0 and commission_sen >= 0 and net_sen >= 0),
  -- The arithmetic is checked by the database, in integers. A rounding bug in
  -- application code cannot produce a statement that does not add up.
  constraint technician_earnings_balances
    check (net_sen = gross_sen - commission_sen),
  constraint technician_earnings_released_has_timestamp
    check (status <> 'released' or released_at is not null)
);

create index technician_earnings_technician_idx
  on public.technician_earnings (technician_id, created_at desc);

create index technician_earnings_pending_idx
  on public.technician_earnings (status, created_at)
  where status = 'pending';

create trigger technician_earnings_set_updated_at
  before update on public.technician_earnings
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Commission
-- ---------------------------------------------------------------------------

create or replace function public.calculate_commission(
  gross_sen bigint,
  commission_percent numeric
)
returns bigint
language sql
immutable
as $$
  -- numeric throughout, then a single round to whole sen. Doing this in
  -- floating point is how a statement ends up one sen out.
  select round(gross_sen::numeric * commission_percent / 100)::bigint;
$$;

comment on function public.calculate_commission is
  'The only place commission is computed. Called by the release-payment Edge '
  'Function; never reimplemented in Dart or TypeScript.';
