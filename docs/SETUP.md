# Setup

From a clean machine to a running app with seeded data.

## 1. Prerequisites

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter | 3.38+ (stable) | Brings Dart 3.10+ |
| Supabase CLI | 2.x | `npm i -g supabase` or `brew install supabase/tap/supabase` |
| Docker Desktop | current | Required by the Supabase CLI for the local stack |
| Node.js | 20+ | For the Supabase CLI and the admin console |
| Android Studio | current | Android SDK 35, an emulator or a device |
| Xcode | 15+ | macOS only, for iOS |

Check Flutter first:

```bash
flutter doctor
```

Resolve anything it flags before continuing. On Windows, if `flutter` is not on
your PATH, add the SDK's `bin` directory (for example `C:\dev\flutter\bin`) to
your user PATH.

## 2. Clone and install

```bash
git clone <repository-url> readytech
cd readytech
cd app && flutter pub get && cd ..
```

## 3. Start Supabase

```bash
supabase start
```

First run pulls several containers and takes a few minutes. When it finishes it
prints the local credentials:

```
API URL: http://127.0.0.1:54321
    DB URL: postgresql://postgres:postgres@127.0.0.1:54322/postgres
Studio URL: http://127.0.0.1:54323
  Inbucket: http://127.0.0.1:54324
 anon key: eyJhbGciOi...
```

Keep this. You need the API URL and the anon key in the next step. If you lose
it, `supabase status` prints it again.

## 4. Environment

Two files, for two different audiences.

**The Flutter app** reads compile-time values from `app/env/`:

```bash
cd app/env
cp development.json.example development.json
```

Fill in `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` with the API URL and anon
key from step 3.

**Everything server-side** reads the repository root `.env`:

```bash
cp .env.example .env
```

Both are gitignored. Read the comments in `.env.example` before filling it in -
it explains which values are safe to ship in an app and which are not.

## 5. Database

```bash
supabase db reset
```

This drops the local database, replays every migration in
`supabase/migrations/`, then runs `supabase/seed.sql`. Run it whenever you pull
new migrations.

The seed refuses to run against a database containing any account whose email
is not `@readytech.test`, so it cannot be applied to something real by accident.

### What you get

| Accounts | Password |
| --- | --- |
| `adam@readytech.test` … `daniel@readytech.test` (6 customers) | `ReadyTech123!` |
| `ahmad@readytech.test` … `priya@readytech.test` (10 technicians) | `ReadyTech123!` |
| `admin@readytech.test` | `ReadyTech123!` |

Plus 12 service categories, technicians spread across Kuala Lumpur, Petaling
Jaya and Shah Alam, and five service requests parked at different points of the
lifecycle - one complete with diagnosis, quotation, payment, warranty and
review; one awaiting quotation approval; one live with a technician on the way;
one still matching; one cancelled.

Sign in as `adam@readytech.test` for the finished-job history, `wei@readytech.test`
for the pending quotation, `kumar@readytech.test` for the live emergency job.

## 6. Google Maps

Not needed for Phase 1, which has no map screens. Set it up before Phase 5.

1. In the Google Cloud console, enable **Maps SDK for Android**, **Maps SDK for
   iOS**, **Directions API** and **Distance Matrix API**.
2. Create two client keys and restrict them - Android by package name
   (`com.readytech.readytech`) plus SHA-1, iOS by bundle id. An unrestricted
   maps key is a bill waiting to happen.
3. Create a third, server-side key restricted by IP, for Edge Functions.
4. Put the client key in `app/env/development.json` as `GOOGLE_MAPS_API_KEY`,
   and add the platform entries:

   **`app/android/app/src/main/AndroidManifest.xml`**, inside `<application>`:

   ```xml
   <meta-data android:name="com.google.android.geo.API_KEY"
              android:value="${GOOGLE_MAPS_API_KEY}" />
   ```

   **`app/ios/Runner/AppDelegate.swift`**:

   ```swift
   GMSServices.provideAPIKey(Bundle.main.object(
     forInfoDictionaryKey: "GOOGLE_MAPS_API_KEY") as! String)
   ```

Keep the server key out of both. It belongs in Edge Function secrets.

## 7. ToyyibPay

Not needed for Phase 1. Set it up before Phase 7, and start with the sandbox.

1. Register at <https://dev.toyyibpay.com> (sandbox) and create a category.
2. Put the secret key and category code in `.env`.
3. Push them to Edge Functions:

   ```bash
   supabase secrets set \
     TOYYIBPAY_BASE_URL=https://dev.toyyibpay.com \
     TOYYIBPAY_SECRET_KEY=... \
     TOYYIBPAY_CATEGORY_CODE=...
   ```

Never put a ToyyibPay secret in `app/env/*.json`. Those values are compiled into
the mobile app and can be read out of the APK.

Production credentials are configured only on the production project, and only
when Phase 7 is ready to go live. Do not put a live key next to a sandbox key
where the two can be confused.

## 8. Run

```bash
cd app
flutter run --dart-define-from-file=env/development.json
```

The `--dart-define-from-file` flag is not optional. Without it the app starts on
a "ReadyTech is not configured" screen listing what is missing, which is
deliberate - a blank screen or a crash would be worse.

### In your editor

**VS Code** - `app/.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "ReadyTech (development)",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": ["--dart-define-from-file", "env/development.json"]
    }
  ]
}
```

**Android Studio** - Run → Edit Configurations → Additional run args:
`--dart-define-from-file=env/development.json`

## 9. Verify

```bash
cd app
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

All three should be clean. Then sign in as `adam@readytech.test` and confirm you
land on the customer home screen with the greeting and the Get Help button.

### Confirming email locally

Local Supabase does not send real mail. Confirmation and reset links go to the
local mailbox at <http://127.0.0.1:54324>. Open it, find the message, click the
link.

After creating an account the app shows **Verify your email**. Open the link
from the mailbox in any browser - it does not have to be on the device running
the app - then tap **I have verified**. The app signs you in and takes you to
the home for the role you registered as: customer or technician.

## 10. Admin console

```bash
cd admin
cp .env.example .env.local     # same URL and publishable key as the app,
                               # but the URL is http://127.0.0.1:54321
npm install
npm run dev                    # http://localhost:3001
```

To administer with your own account rather than a seeded one: sign up in the
app, confirm the email, then appoint yourself from the database - the one time
it has to be done that way:

```bash
docker exec -i supabase_db_readytech psql -U postgres -d postgres \
  -v email=you@example.com < supabase/snippets/appoint_first_admin.sql
```

Sign in at <http://localhost:3001>. A technician who registers in the app shows
up under **Technicians → Not submitted**; approving them there is what lets
matching offer them work.

If you pulled this without resetting, apply the new migration without wiping
your data: `npx supabase migration up --local` from the repository root.

## Troubleshooting

**"ReadyTech is not configured" on launch.** You ran without
`--dart-define-from-file`, or `development.json` is missing values. The screen
names them. Note that editing `.env` or `.env.example` will not help — the app
reads `app/env/<flavor>.json`, and it reads it at build time. In VS Code use the
**ReadyTech (local)** launch configuration, which already carries the flag.

**App starts but cannot reach the local database from an Android emulator.**
Check the URL is `http://10.0.2.2:54321`, not `127.0.0.1`. Inside an emulator,
loopback is the emulator itself; `10.0.2.2` is your machine. See
[app/env/README.md](../app/env/README.md).

**`supabase start` fails.** Docker Desktop is not running, or ports 54321-54324
are in use. `supabase stop --no-backup` then start again.

**`supabase db reset` fails on the PostGIS extension.** The local image ships
with PostGIS available; if it fails, `supabase stop --no-backup` and start again
to pull a current image.

**Seed refuses to run.** It found an account not ending in `@readytech.test`.
That is the guard working. Confirm you are pointed at your local database, not
a real project.

**Sign-in returns "Please verify your email address".** The account exists but
is unconfirmed. Check Inbucket.

**Analysis fails after a pull.** `flutter pub get`, then
`dart run build_runner build --delete-conflicting-outputs` if generated files
are involved.

**Sign-in returns "Database error querying schema".** Something inserted into
`auth.users` while leaving `confirmation_token`, `recovery_token`,
`email_change_token_new` or `email_change` NULL. Those columns are nullable in
the table but GoTrue scans them into a non-nullable string, so it fails on every
account it reads. The seed sets them to `''` for this reason; if you add
accounts by hand, do the same.

**"permission denied for table …" from a signed-in client.** The role grants in
`20260101001600_grants.sql` did not run. Re-run `supabase db reset`. Row Level
Security is only consulted after Postgres has checked the table privilege, so a
missing grant looks like a total outage rather than a policy problem.
