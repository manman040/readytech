# ReadyTech admin console

The desk side of ReadyTech: verification, disputes, jobs, accounts, the service
catalogue, pricing, payments, moderation and the audit trail.

## Why it is separate from the mobile app

Administration is desk work. A verification queue with identity documents side
by side, a dispute with the chat log, the evidence photographs, the quotation
and the payment all visible at once, a pricing table — none of that fits on a
phone. The mobile app keeps a small admin landing screen that points here.

## Running it

```bash
supabase start                       # or: the stack is already running
cd admin
cp .env.example .env.local           # paste the API URL and publishable key
npm install
npm run dev                          # http://localhost:3001
```

Port 3001, so it can run beside anything else on 3000.

### Becoming an administrator

An administrator is appointed, never self-declared — sign-up refuses `admin`
whatever the client asks for. So:

1. Sign up in the app like anyone else and confirm the email.
2. **First administrator of an environment:** someone with database access runs
   ```bash
   docker exec -i supabase_db_readytech psql -U postgres -d postgres \
     -v email=you@example.com < supabase/snippets/appoint_first_admin.sql
   ```
   (on a hosted project, paste the snippet into the SQL editor).
   **Every one after that:** an existing administrator opens *Accounts → the
   person → Role*. Both paths are written to the audit log.
3. Sign in to the console with the same email and password.

A customer or technician who signs in here is told the console is not for
them and signed straight back out.

## What it does

| Area | What an administrator can do |
| --- | --- |
| Overview | Queue counts, live jobs, jobs by status, money totals |
| Jobs | Search and filter every request; see the timeline, quotations, payments, evidence, conversation, offer ledger and live match ranking; move a job where the transition table allows an admin to (cancel, send back to matching, dispute outcomes) |
| Disputes | Read the evidence, mark under review, uphold or reject, record the refund owed, choose where the job goes next |
| Verification queue | View private documents through ten-minute signed links; approve or reject each one |
| Technicians | Approve, reject, suspend, reinstate; reputation, skills, earnings, recent jobs |
| Accounts | Find anyone; change a role (never your own) |
| Service catalogue | Add, edit, hide categories and their fees |
| Pricing | Edit every `pricing_config` knob, including matching weights |
| Payments & earnings | Read-only |
| Moderation | Dismiss or remove reported messages; remove reviews |
| Audit log | Every action above, append-only |

## How it is put together

```
src/
  app/
    login/              Sign-in (server action)
    (console)/          Everything behind requireAdmin()
      <area>/page.tsx   Server components that read as the admin
      <area>/actions.ts Server actions, one admin_* call each
  components/           Chips, tables, cards, ActionForm
  lib/
    domain/             TypeScript twins of the app's Dart models
    supabase/server.ts  Per-request client with the admin's session
    auth.ts             requireAdmin() - asks Postgres, not the token
    errors.ts           RT400/403/404/409 verbatim, everything else generic
  proxy.ts              Session refresh + "signed in?" redirect
```

### Security

**No service-role key.** The console signs in as an ordinary Supabase user and
talks to Postgres with that user's JWT, exactly like the app. Its extra reach is
the `is_admin()` policies that already exist and the `admin_*` functions in
`supabase/migrations/20261005000200_admin_console.sql`. Take the role away and
the console stops working on the next request — not when a token expires, and
not when someone remembers to rotate a key.

**Writes go through Postgres functions, not Edge Functions.** The original plan
for this directory said privileged actions would go through Edge Functions. They
go through `SECURITY DEFINER` functions instead, for the reason that plan gave:
one place for the rules and the audit trail. Each function checks `is_admin()`,
does its work in one transaction (approving a technician touches the document,
the profile and their notifications), writes `admin_audit_log`, and lets the
existing triggers — the status guard, the column guards, the rating refresh —
rule exactly as they do for the app. Nothing needs a provider call, so there is
no reason to leave the database.

**Money is not the console's to move.** Payments and earnings are read-only here
for administrators too. A dispute records the refund *owed*; issuing it is a
ToyyibPay call that belongs to the payment Edge Functions (Phase 7/8).

**The audit log is append-only for everyone.** No policy and no privilege lets
any signed-in user, administrators included, update or delete an entry.

### Staying in step with the app

`lib/domain/` keeps the console's copies of the status labels, colours, money
formatting and enum wording. `test/domain.test.ts` reads the migrations and the
Dart sources directly and fails if any of them drift: a new status, a renamed
label, a changed chip colour.

## Checks

```bash
npm run typecheck
npm test                       # vitest: domain mirrors, money, errors, pricing
npm run build
```

Backend rules for the console are in `supabase/tests/05_admin_console.sql`.

## Not built yet

- Refunds and payouts themselves (need the Phase 7 payment functions)
- Sending ad-hoc notifications, reports and exports, settings
- Average response and completion time on the overview
