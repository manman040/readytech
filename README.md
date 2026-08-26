# ReadyTech

An on-demand IT service marketplace. A customer describes a problem in their own
words; ReadyTech classifies it, matches a nearby verified technician, tracks
them to the door, and manages the job through diagnosis, quotation, approval,
repair, payment and warranty.

> **Tell us what's wrong. ReadyTech handles the rest.**

The product is not "an app that books technicians". It is the system that both
sides of a repair can trust when neither can verify the other: the state
machine, the quotation that cannot be silently changed, the payment that only a
server can settle, and the evidence that cannot be deleted after a dispute
starts.

## Status

**Phase 1 — Foundation. Complete.**

| Delivered | |
| --- | --- |
| Flutter app | Clean architecture, Material 3 design system, routing, DI |
| Authentication | Sign up, sign in, sign out, password reset, email verification, session restore |
| Database | 30 tables covering the whole lifecycle, with constraints and indexes |
| Security | Row Level Security on every table, column-level write protection |
| State machine | 20 statuses, transition table enforced by a Postgres trigger |
| Matching | Server-side ranking and race-free job acceptance |
| Seed data | 17 accounts, 12 categories, 5 jobs across the lifecycle |
| Tests | 127 Dart tests passing, plus three SQL suites run against live Postgres |

Verified end to end, not just compiled: `flutter analyze` clean, 127 tests
green, a debug APK built, all 18 migrations applied to a real Postgres 17 +
PostGIS both locally and on a hosted Supabase project, and the whole job
lifecycle walked through as real signed-in users. See
[supabase/tests/](supabase/tests/).

### Environments

| | Where | Data |
| --- | --- | --- |
| development | local `supabase start` | full seed - 17 accounts, 5 jobs across the lifecycle |
| staging | hosted project, `ap-southeast-1` | reference data only; the seed refuses to run |

Reference data (12 service categories, 15 pricing keys, the 53-row transition
table) ships in migrations, so it reaches every environment. Demo accounts and
sample jobs live in `seed.sql` and reach only local.

Phases 2-10 are scoped in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). The
Phase 1 schema already covers the whole lifecycle, so later phases add screens
and Edge Functions against tables that exist rather than migrating a live
database.

## Quick start

```bash
git clone <repository-url> readytech && cd readytech

supabase start            # prints your local API URL and anon key
cp app/env/development.json.example app/env/development.json
#   ...paste the API URL and anon key into that file
supabase db reset         # migrations + seed data

cd app
flutter pub get
flutter run --dart-define-from-file=env/development.json
```

Sign in with `adam@readytech.test` / `ReadyTech123!`.

Full instructions, including Google Maps and ToyyibPay, are in
[docs/SETUP.md](docs/SETUP.md).

## Layout

```
readytech/
  app/          Flutter app - customer and technician
  supabase/     Migrations, RLS policies, Edge Functions, seed data
  admin/        Next.js admin console (Phase 9)
  docs/         Architecture, setup, deployment
```

## Documentation

| | |
| --- | --- |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | How the system is put together and why |
| [docs/SETUP.md](docs/SETUP.md) | Clean machine to running app |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Environments, builds, release checklist |
| [supabase/functions/README.md](supabase/functions/README.md) | What runs server-side and why it has to |
| [supabase/tests/README.md](supabase/tests/README.md) | Database verification suites, and why they run as real users |
| [app/env/README.md](app/env/README.md) | Build-time configuration |

## Working on it

```bash
cd app
flutter analyze                              # must be clean
flutter test                                 # must be green
dart format lib test
flutter run --dart-define-from-file=env/development.json
```

Backend:

```bash
supabase db reset                            # replay migrations + seed
supabase migration new <name>                # new migration
supabase db diff --linked                    # what would be pushed
```

### Building

```bash
cd app
flutter build appbundle --release --dart-define-from-file=env/production.json
flutter build ipa       --release --dart-define-from-file=env/production.json
```

`--dart-define-from-file` is required. Without it the app starts on a
"not configured" screen naming the missing values — deliberately, because a
blank screen would be worse.

## Rules the code enforces

These are not conventions; they are constraints, triggers and policies. They
hold whatever a client does.

1. Repair cannot start until the customer approves a quotation.
2. An approved quotation is immutable. Extra work is a new version with its own
   approval.
3. A job is marked paid only by the server, only after it has confirmed the
   payment with the provider itself.
4. Two technicians cannot be assigned the same job, and one technician cannot
   hold two live jobs.
5. A technician cannot check in without the code the customer reads out.
6. The customer's address is not visible to a technician who has only been
   offered the job.
7. Service history is never deleted by a user action. Cancellation is a status.
8. Evidence is append-only, including for the person who uploaded it.
9. Currency is a whole number of sen, and the arithmetic is checked by database
   constraints.
10. A user's role lives in a table only an administrator can write.

## Stack

Flutter 3.38 · Dart 3.10 · Material 3 · flutter_bloc · get_it · go_router ·
Supabase (Postgres 17, Auth, Storage, Realtime, Edge Functions) · PostGIS ·
Google Maps · ToyyibPay · Next.js (admin)
