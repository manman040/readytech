# ReadyTech architecture

## The problem this shape solves

ReadyTech is a marketplace where a stranger comes to your home or office,
opens your device, tells you what is wrong with it, and names a price. Almost
every architectural decision here follows from that sentence.

The customer cannot verify the diagnosis. The technician cannot verify that
they will be paid. Neither can be trusted to report the outcome. So the system
has to be the thing both sides trust, which means the important facts have to
live somewhere neither side controls.

That gives three rules the whole codebase is arranged around:

1. **The backend decides.** Job status, prices, payments and assignments are
   decided by Postgres and Edge Functions. The mobile app renders those
   decisions and asks for changes; it never makes one.
2. **The record is permanent.** Nothing in a service history is deleted through
   a normal user action. Cancellation is a status. Evidence is append-only.
3. **Money is integers.** Currency is a whole number of sen everywhere, and the
   authoritative arithmetic happens server-side.

## Layout

```
readytech/
  app/          Flutter mobile app (customer + technician)
  supabase/     Schema, RLS, Edge Functions, seed data
  admin/        Next.js admin console
  docs/         This directory
```

## Mobile app

```
app/lib/
  core/         Cross-cutting: config, DI, errors, theme, widgets, helpers
  data/         Models, data sources, repositories
  features/     One directory per feature: bloc + view + widgets
  routing/      Route table and the single redirect guard
```

The dependency direction is one way: `features` depend on `data`, `data`
depends on `core`, and nothing depends on `features`. A widget never touches
Supabase; it talks to a bloc, which talks to a repository.

### State management

`flutter_bloc` with `get_it` for the object graph, matching the conventions in
the team's existing Flutter work.

- **`AuthBloc`** is app-wide and lives for the process. It is the only thing
  that answers "who is using this app", and the router reads it.
- **Form cubits** (`LoginCubit`, `SignUpCubit`, …) are created by the screen
  that owns them and disposed with it.

Registration in `core/di/injector.dart` is written by hand rather than
generated. The graph is small enough to read top to bottom, and an explicit
list of what the app depends on is worth more than the boilerplate saved.

### Errors

One path, no exceptions:

```
Supabase SDK throws
  → GuardedRepository.guard catches everything
  → ErrorMapper turns it into a Failure
  → the Failure is logged with its debugDetail
  → the UI shows Failure.message only
```

`Failure` carries two strings. `message` is written for a user and is the only
one a widget may render. `debugDetail` holds the driver text and goes to the log
sink. `context.showFailure(failure)` takes the `Failure` rather than a `String`
precisely so no call site can interpolate the wrong one.

The backend participates in this. Our own Postgres functions raise errors with
SQLSTATEs in the `RT` class:

| SQLSTATE | Meaning | Becomes |
| --- | --- | --- |
| `RT400` | Failed a domain rule | `ValidationFailure` |
| `RT403` | Not permitted | `PermissionFailure` |
| `RT404` | Not found or not visible | `NotFoundFailure` |
| `RT409` | Lost a race, or an illegal transition | `ConflictFailure` |

Raising one of these is a promise that the message was written for a human, so
`ErrorMapper` surfaces it verbatim. Every other database error is replaced with
a generic message, because a Postgres error string leaks the schema.

### Money

`core/utils/money.dart` holds a whole number of sen. There is no `double`
anywhere near a price. Binary floating point cannot represent 0.10 exactly, so
repeated addition drifts, and a receipt that is one sen out is a support ticket
and a trust problem at the same time.

The client type exists for rendering and for pre-diagnosis estimates. Quotation
totals, platform commission and technician earnings are computed in Postgres and
checked by constraints - `technician_earnings` has
`check (net_sen = gross_sen - commission_sen)`, so an arithmetic bug in
application code cannot produce a statement that does not add up.

## The state machine

A service request moves through a closed set of statuses. There are three
copies of the transition rules and they exist for different reasons:

| Where | Purpose |
| --- | --- |
| `service_status_transitions` table | **The authority.** Data, so a change is a reviewed migration. |
| `service_request_status_guard()` trigger | Enforces it on every write. |
| `ServiceStatus` in Dart | Lets the UI hide buttons that would be rejected. |

The Dart copy never grants anything. If it disagrees with the database, the
database wins and the user sees a `ConflictFailure`. `service_status_test.dart`
asserts the shape of the Dart table - every status reachable, every transition
with an actor, no self-transitions.

Guards the transition table cannot express live in the trigger:

- `CHECKING_IN` requires `arrival_code_verified_at`. Without it a technician
  could start billable work having never reached the door.
- `REPAIRING` from `APPROVED` requires an approved quotation to exist.
- `REPAIRING` from `ADDITIONAL_QUOTE_PENDING` requires the *additional*
  quotation to be approved, not merely submitted.
- `PAID` requires a payment row with `status = 'paid'` and a non-null
  `verified_at`.

## Authorisation

Three layers, each doing a different job:

**Routing** (`routing/app_router.dart`) is a single `redirect`. It decides which
screen a user sees. It is a convenience, not a boundary — the pure function
`redirectFor` is unit tested.

**Row Level Security** is the boundary. Every table denies by default. The tests
that matter are in the policies: a technician sees a customer's device only
through a job they hold; a customer's saved addresses are never visible to a
technician at all; `payments` has no write policy for anybody.

**Column protection** is the layer RLS cannot provide. A customer may update
their own service request — but `service_requests_protect_columns()` rejects any
update that changes the assigned technician, the estimate or the arrival code.
Similarly `technician_profiles_protect_columns()` stops a technician awarding
themselves a verification or a rating.

**Registration** is the one place a client influences a role. Sign-up metadata
may ask for `technician`, and `handle_new_user()` honours exactly that value:
the account gets a `technician` role and an unverified `technician_profiles`
row in the same transaction. That is safe because the role alone grants
nothing — matching, visibility to customers and every job-scoped policy key on
an *approved* verification, which only an administrator can set. `admin` is
never read from metadata; anything other than `technician` becomes a customer.
`supabase/tests/04_technician_registration.sql` proves all of this as the
freshly registered user.

Underneath all three sit **table privileges**, in
`20260101001600_grants.sql`. Postgres checks the privilege before it evaluates a
policy, so this is the coarse gate: `payments` grants `SELECT` and nothing else
to `authenticated`, and `service_requests` grants no `DELETE` to anyone. Adding
a write policy to `payments` by mistake would still not be enough to let a phone
settle its own bill.

The grants are written out rather than left to the platform's defaults, and
they **revoke before granting**. Both halves were learned the hard way.

Locally, tables are owned by `postgres`, whose default ACL in this schema grants
neither `SELECT` nor `INSERT` to `authenticated` and grants `EXECUTE` on
functions to nobody — so relying on defaults produced a database where every
client query failed with "permission denied" before a policy was ever consulted.

A hosted project starts from the opposite position: `authenticated` begins with a
broad grant. So a migration that only *adds* privileges was a no-op there, and
`authenticated` kept `INSERT` on `payments`. Policies still refused the write —
nothing was exposed — but the privilege layer is meant to be the backstop
*underneath* the policies, and a backstop that only exists in development is not
a backstop. `20260101001800_grants_hardening.sql` revokes everything from
`authenticated` in this schema and then grants back exactly the intended set, so
the outcome no longer depends on where the database came from.

The lesson generalises: a grant migration that does not revoke is not
idempotent across environments.

### Trusted internal writes

The column guards create a problem the system has to solve explicitly: our own
code writes the columns they protect. The counter-refresh trigger updates
`technician_profiles`; `accept_job_offer()` sets `assigned_technician_id`. Those
writes carry the caller's JWT — `SECURITY DEFINER` changes the role, not
`auth.uid()` — so to a guard they are indistinguishable from the tampering it
exists to stop.

`is_internal_write()` draws the line, on two narrow signals:

- `pg_trigger_depth() > 1`, meaning the write originated inside another
  trigger. A statement from a client always arrives at depth 1.
- A transaction-local flag that a trusted `SECURITY DEFINER` function raises
  immediately before its privileged write and lowers immediately after.

A client cannot raise the flag: PostgREST executes no arbitrary SQL and exposes
only functions in `public`, so there is no route to `set_config()`.

`current_service_actor()` consults the same helper, which is what lets
`accept_job_offer()` perform the `MATCHING → ASSIGNED` transition. At that
moment the job is still unassigned, so the accepting technician matches neither
the customer nor the (null) assigned technician — without this they would be
classified as a stranger and refused.

### Location privacy

The customer's exact address is the most sensitive field in the schema, so
exposure is staged:

| Stage | What a technician can see |
| --- | --- |
| Offered a job | Category, urgency, estimate, distance, and coordinates rounded to ~100 m — through `technician_open_offers()`, not through the table |
| Accepted | Full coordinates and address, via the RLS policy on `service_requests` |
| Checked in | Unchanged; the arrival code has confirmed both parties are present |

A technician who has merely been offered a job has no select permission on
`service_requests` at all. Without that redacted function, every offer would
hand a stranger's home address to someone who has not committed to attending.

Live technician position is equally staged. `technician_locations` holds **one
row per technician** — the current position, not a track. Retaining a history of
where a person has been is a liability with no product use. A customer can read
it only while that technician is assigned to *their* job and is in
`ASSIGNED`, `TECHNICIAN_ON_THE_WAY` or `ARRIVED`.

## Admin console

`admin/` is a Next.js app that signs in as an administrator's own Supabase
account. It holds no service-role key, so it is subject to the same RLS as the
phone: its reach is the `is_admin()` policies plus the `admin_*` functions in
`20261005000200_admin_console.sql`.

Every administrative write is one of those functions rather than a direct table
write, for three reasons. An action like approving a technician touches several
rows and must not stop halfway. Notifications have no client insert path at all.
And the one role that can override almost anything is the one whose actions most
need recording, so each function appends to `admin_audit_log`, which no
signed-in user, administrators included, can update or delete. The functions
change status through the normal guard, so the transition table still decides
what an admin may do; `admin` is just another actor in it.

The console mirrors the app's status labels, chip tones and money formatting in
`admin/src/lib/domain/`, and its tests read the Dart sources and migrations to
fail on drift. Same rule as the Dart copy: the mirror renders, it never grants.

## Preventing double booking

Two technicians tap Accept at the same instant. This is handled three times
over, deliberately:

1. `accept_job_offer()` takes `SELECT … FOR UPDATE` on the request. The second
   caller blocks, then finds a status that is no longer `MATCHING`.
2. `service_requests_one_active_per_technician_idx` — a partial unique index —
   makes a second live assignment impossible at the storage layer.
3. `technician_assignments_single_acceptance_idx` does the same for the offer
   ledger.

The lock is the mechanism; the indexes are there because a lock only helps the
code paths that remember to take it.

The same pattern protects the customer: `service_requests_one_active_per_customer_idx`
means a double-tapped "Get Help" cannot create two jobs, no matter what the
client does.

## Realtime

Published tables are only the ones the app subscribes to: `service_requests`,
`technician_locations`, `messages`, `notifications`, `quotations`,
`technician_assignments`. Publication has a cost — every write is decoded from
the WAL — so service history, pricing and reputation are fetched on demand.

Publication is not authorisation. Realtime applies the same RLS policies as any
other read, so a subscriber receives only rows it could have selected.

`REPLICA IDENTITY FULL` is set on `service_requests`, `quotations` and
`technician_assignments`. Without it an update event carries only the primary
key, and the timeline cannot tell which status a job moved *from*.

## Offline

Connectivity drives an advisory banner and retry decisions, and nothing else.
The app never infers from "the request appeared to succeed" that a payment
settled or a job completed — those are re-read from the backend. A stale
"payment successful" is worse than an obvious failure.

## Extension points

Designed in from the start, implemented when the phase arrives:

- **Problem classification** is a `ProblemClassifier` contract with a rule-based
  implementation first. An AI implementation is a swap, and the core flow works
  with the AI service unavailable. `service_requests` records
  `classified_by`, so a bad classification can be traced to what produced it.
- **Payments** sit behind an abstraction with ToyyibPay first. The provider's
  identifiers are isolated in `payments.provider_*`.
- **Maps** sit behind a provider interface so Google Maps can be replaced.
- **Pricing** is entirely in `pricing_config` and `service_categories`. No fee
  is hardcoded in a widget.

## Delivery phases

| Phase | Scope | State |
| --- | --- | --- |
| 1 | Foundation: architecture, theme, routing, auth, schema, RLS, seed | **Done** |
| 2 | Customer core: home, devices, problem reporting, request creation | Next |
| 3 | Technician core: profile, verification, availability, job requests | |
| 4 | Matching: ranking, top 3, auto match | |
| 5 | Realtime: status, tracking, notifications, chat | |
| 6 | Execution: arrival, evidence, diagnosis, quotation, repair | |
| 7 | Financial: ToyyibPay, verification, receipts, earnings | |
| 8 | Trust: warranty, reviews, disputes | |
| 9 | Admin console: verification, disputes, jobs, accounts, catalogue, pricing, moderation, audit log | **Done** (refunds and payouts wait on 7) |
| 10 | Polish: performance, accessibility, offline, hardening | |

The Phase 1 schema covers the whole lifecycle, not just what Phase 1 uses. That
is deliberate: a later phase adds screens and Edge Functions against tables that
already exist, rather than migrating a live database.
