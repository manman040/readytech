# Database verification

Scripts that exercise the rules the schema is supposed to enforce, against a
running local stack. They are the backend counterpart to `flutter test`.

## Running them

```bash
supabase db reset          # start from a known state
supabase test              # (pgTAP, not used here)

# Run a suite:
docker exec -i supabase_db_readytech psql -U postgres -d postgres -q \
  < supabase/tests/01_business_rules.sql
```

On Windows PowerShell, `docker` may resolve to a stub in `system32`; use
`docker.exe` explicitly:

```powershell
Get-Content supabase\tests\01_business_rules.sql -Raw |
  docker.exe exec -i supabase_db_readytech psql -U postgres -d postgres -q
```

Suites 2 and 3 roll back everything they do. Suite 1 leaves a couple of rows
behind, so re-run `supabase db reset` afterwards if you care about the state.

## The suites

**`01_business_rules.sql`** — seed integrity, the PostGIS generated columns, the
quotation-totals trigger, and the constraints that hold whatever a caller does:
illegal status transitions, editing an approved quotation, a second concurrent
job for one customer, and an earnings row that does not balance.

**`02_row_level_security.sql`** — isolation, checked as real signed-in users.
How many rows a customer, a technician and an unrelated account can each see;
that a technician cannot edit their own reputation or verification but can set
their own availability; that a customer cannot promote themselves, write a
payment, reassign their job or rewrite their estimate; and that a technician
holding only an *offer* gets the redacted feed and zero rows from
`service_requests`.

**`03_lifecycle_walkthrough.sql`** — a complete job from request to warranty,
performed by real authenticated users, asserting both what must succeed and what
must be refused at each step.

## Why "as real users" matters

The seed runs as `postgres`, where `auth.uid()` is NULL and every guard
short-circuits on its first condition. A rule can therefore look correct in
seeded data and still fail — or fire against the system's own bookkeeping — the
moment a signed-in user touches it.

Two bugs found exactly this way, both invisible to seeding and to a SQL parser:

- The technician counter-refresh trigger updates `technician_profiles`, which
  the column guard on that table rejected, so **any** status change by a real
  user failed.
- `accept_job_offer()` sets `assigned_technician_id` and moves the job from
  `MATCHING` to `ASSIGNED` — both of which its own guards refused, so **no
  technician could ever accept a job**.

Both are fixed by `is_internal_write()`; see docs/ARCHITECTURE.md.

## Setting a role in psql

`SET LOCAL` is silently ignored outside a transaction, which leaves the session
running as superuser and RLS bypassed — every assertion then passes for the
wrong reason. Each block in these suites is an explicit `BEGIN … ROLLBACK`:

```sql
begin;
select set_config('request.jwt.claims',
  '{"sub":"<user-uuid>","role":"authenticated"}', true);
set local role authenticated;
-- ... assertions ...
rollback;
```
