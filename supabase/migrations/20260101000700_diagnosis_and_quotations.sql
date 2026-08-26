-- ReadyTech :: diagnosis and quotations
--
-- The rule this schema exists to enforce: a technician cannot silently change
-- a price the customer already agreed to. An approved quotation is immutable;
-- extra work becomes a new versioned quotation that needs its own approval.

create table public.diagnoses (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  technician_id uuid not null
    references public.technician_profiles (id) on delete restrict,

  problem_found text not null,
  notes text,
  recommended_action text not null,
  -- Set when the fault turns out not to match what the customer described.
  revised_category_id uuid
    references public.service_categories (id) on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint diagnoses_problem_length
    check (char_length(problem_found) between 3 and 2000),
  constraint diagnoses_action_length
    check (char_length(recommended_action) between 3 and 2000)
);

create index diagnoses_request_idx
  on public.diagnoses (request_id, created_at desc);

create trigger diagnoses_set_updated_at
  before update on public.diagnoses
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- quotations
-- ---------------------------------------------------------------------------

create table public.quotations (
  id uuid primary key default extensions.gen_random_uuid(),
  request_id uuid not null
    references public.service_requests (id) on delete cascade,
  technician_id uuid not null
    references public.technician_profiles (id) on delete restrict,
  diagnosis_id uuid references public.diagnoses (id) on delete set null,

  kind public.quotation_kind not null default 'initial',
  -- Monotonic per request. Referenced by the approval record so a receipt can
  -- name exactly which version the customer agreed to.
  version integer not null,
  status public.quotation_status not null default 'draft',

  -- Totals are computed from quotation_items by a trigger. A client-supplied
  -- total is not accepted, so the itemisation and the amount charged cannot
  -- disagree.
  subtotal_sen bigint not null default 0,
  platform_fee_sen bigint not null default 0,
  total_sen bigint not null default 0,

  notes text,
  valid_until timestamptz,
  submitted_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  unique (request_id, version),
  constraint quotations_amounts_non_negative
    check (subtotal_sen >= 0 and platform_fee_sen >= 0 and total_sen >= 0),
  constraint quotations_submitted_when_not_draft
    check (status = 'draft' or submitted_at is not null)
);

comment on table public.quotations is
  'Additional work never edits an approved quotation. It is a new row with '
  'kind = additional and the next version number.';

create index quotations_request_idx
  on public.quotations (request_id, version desc);

-- At most one quotation per request can be awaiting a decision. Without this,
-- two submissions in flight would both present themselves to the customer.
create unique index quotations_single_open_idx
  on public.quotations (request_id)
  where status = 'submitted';

create trigger quotations_set_updated_at
  before update on public.quotations
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- quotation_items
-- ---------------------------------------------------------------------------

create table public.quotation_items (
  id uuid primary key default extensions.gen_random_uuid(),
  quotation_id uuid not null
    references public.quotations (id) on delete cascade,

  kind public.quotation_item_kind not null,
  description text not null,
  quantity integer not null default 1,
  unit_price_sen bigint not null,
  -- Stored rather than derived so a receipt reproduces exactly, even if the
  -- rounding rule for a line ever changes.
  amount_sen bigint not null,
  sort_order integer not null default 0,

  created_at timestamptz not null default now(),

  constraint quotation_items_quantity_positive check (quantity > 0),
  constraint quotation_items_prices_non_negative
    check (unit_price_sen >= 0 and amount_sen >= 0),
  constraint quotation_items_amount_matches
    check (amount_sen = unit_price_sen * quantity),
  constraint quotation_items_description_length
    check (char_length(description) between 1 and 200)
);

create index quotation_items_quotation_idx
  on public.quotation_items (quotation_id, sort_order);

-- ---------------------------------------------------------------------------
-- quotation_approvals
-- ---------------------------------------------------------------------------

create table public.quotation_approvals (
  id uuid primary key default extensions.gen_random_uuid(),
  quotation_id uuid not null
    references public.quotations (id) on delete cascade,
  -- Denormalised so the version a customer agreed to is pinned in the approval
  -- record itself, not looked up later through a row that might have moved on.
  quotation_version integer not null,
  approved_by uuid not null references public.profiles (id) on delete restrict,
  decision text not null,
  note text,
  approved_at timestamptz not null default now(),

  unique (quotation_id),
  constraint quotation_approvals_decision_values
    check (decision in ('approved', 'declined'))
);

comment on table public.quotation_approvals is
  'One decision per quotation, enforced by the unique index. A customer cannot '
  'approve and then quietly un-approve a price the work was started on.';

create index quotation_approvals_approver_idx
  on public.quotation_approvals (approved_by, approved_at desc);

-- ---------------------------------------------------------------------------
-- Totals
-- ---------------------------------------------------------------------------

create or replace function public.recalculate_quotation_totals()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  target_quotation uuid := coalesce(new.quotation_id, old.quotation_id);
  items_total bigint;
  fee bigint;
  is_locked boolean;
begin
  select q.status in ('approved', 'declined', 'superseded', 'expired')
    into is_locked
    from public.quotations q
   where q.id = target_quotation
   for update;

  if is_locked then
    raise exception 'This quotation has already been decided and cannot be changed.'
      using errcode = 'RT409';
  end if;

  select coalesce(sum(amount_sen), 0)
    into items_total
    from public.quotation_items
   where quotation_id = target_quotation;

  -- The platform fee applies once per job, so a supplementary quotation does
  -- not charge it a second time.
  select case
           when q.kind = 'initial'
             then coalesce(public.pricing_int('platform_fee_sen'), 0)
           else 0
         end
    into fee
    from public.quotations q
   where q.id = target_quotation;

  update public.quotations
     set subtotal_sen = items_total,
         platform_fee_sen = fee,
         total_sen = items_total + fee
   where id = target_quotation;

  return null;
end;
$$;

create trigger quotation_items_recalculate
  after insert or update or delete on public.quotation_items
  for each row execute function public.recalculate_quotation_totals();

-- Version numbers are assigned by the database. Letting a client pick one
-- invites two concurrent submissions claiming the same version.
create or replace function public.quotations_assign_version()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if new.version is null or new.version = 0 then
    select coalesce(max(version), 0) + 1
      into new.version
      from public.quotations
     where request_id = new.request_id;
  end if;
  return new;
end;
$$;

create trigger quotations_version
  before insert on public.quotations
  for each row execute function public.quotations_assign_version();

-- An approved quotation is a record of an agreement. The only field that may
-- move afterwards is the status, and only to 'superseded'.
create or replace function public.quotations_protect_approved()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if old.status = 'approved' then
    if new.subtotal_sen is distinct from old.subtotal_sen
      or new.platform_fee_sen is distinct from old.platform_fee_sen
      or new.total_sen is distinct from old.total_sen
      or new.version is distinct from old.version
      or new.request_id is distinct from old.request_id
    then
      raise exception
        'An approved quotation cannot be changed. Submit an additional quotation instead.'
        using errcode = 'RT409';
    end if;

    if new.status not in ('approved', 'superseded') then
      raise exception 'An approved quotation cannot return to %.', new.status
        using errcode = 'RT409';
    end if;
  end if;

  return new;
end;
$$;

create trigger quotations_immutable_once_approved
  before update on public.quotations
  for each row execute function public.quotations_protect_approved();
