# Edge Functions

Server-side logic for anything a client must not be trusted to do.

Phase 1 ships the shared foundation in `_shared/`. The functions themselves land
with the features that need them, listed below with their phase - each one is a
deliberate placement, not a to-do list.

## Why these live here and not in the app

Three kinds of operation can never run on a phone:

**Money.** A client that can write to `payments` can mark its own job paid. The
`payments` table has no insert or update policy for anyone; only
`verify-payment`, holding the service role and having called ToyyibPay itself,
settles a payment.

**Authority.** Matching reads a technician's rating, cancellation rate and live
position, and produces a ranking. Exposing those inputs would let a technician
work out how to game the queue, and exposing the output would let a client
assign itself work.

**Races.** Two technicians accepting the same job in the same instant is
resolved by a row lock in `accept_job_offer()`, not by whichever HTTP request
happened to arrive first.

## Functions

| Function | Phase | What it owns |
| --- | --- | --- |
| `calculate-matching` | 4 | Ranks technicians, writes the offer ledger, walks candidates on timeout, expands the radius when nobody accepts. |
| `create-quotation` | 6 | Validates line items against the pricing table, computes totals server-side. |
| `approve-quotation` | 6 | Records the approval and advances the job. Refuses if the quotation has moved on. |
| `create-payment` | 7 | Creates the ToyyibPay bill from the approved quotation. The amount comes from the database, never from the request. |
| `verify-payment` | 7 | The webhook target. Calls ToyyibPay to confirm, then settles. The only path to `status = 'paid'`. |
| `release-payment` | 7 | Computes commission and writes the technician's earning record. |
| `create-warranty` | 8 | Issues the warranty against the completed service and its category rules. |
| `process-cancellation` | 8 | Applies the cancellation policy, decides the fee, writes the record. |
| `resolve-dispute` | 8 | Administrator-only. Applies the outcome, including a refund. |
| `send-notification` | 5 | Writes the notification row and dispatches the push. |

## Conventions

Every function is wrapped in `handle()` from `_shared/http.ts`, which gives it
CORS, method checking and a single error envelope. Errors a user should read are
thrown as `PublicError`; anything else becomes a generic 500 with the detail in
the log.

Establish authority with `callerClient` (policies apply) before doing the
privileged write with `serviceClient` (policies do not). Reaching for
`serviceClient` first is what makes row level security decorative.

```ts
import { handle, jsonResponse, PublicError, readJson } from '../_shared/http.ts';
import { requireRole, serviceClient } from '../_shared/supabase.ts';

Deno.serve(handle('example', async (request) => {
  const { userId, role } = await requireRole(request);
  if (role !== 'admin') throw PublicError.forbidden();

  const body = await readJson<{ requestId: string }>(request);
  const db = serviceClient();
  // ... privileged write
  return jsonResponse(request, { ok: true });
}));
```

## Secrets

Set per environment; never in `app/env/*.json`, which is compiled into the
mobile app.

```bash
supabase secrets set \
  TOYYIBPAY_SECRET_KEY=... \
  TOYYIBPAY_CATEGORY_CODE=... \
  TOYYIBPAY_BASE_URL=https://dev.toyyibpay.com \
  GOOGLE_MAPS_API_KEY_SERVER=... \
  ALLOWED_ORIGINS=https://admin.readytech.example
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected
by the platform.
