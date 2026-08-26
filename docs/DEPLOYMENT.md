# Deployment

Three environments, kept apart:

| Environment | Supabase project | ToyyibPay | Demo mode |
| --- | --- | --- | --- |
| development | local (`supabase start`) | sandbox | on |
| staging | dedicated project | sandbox | on |
| production | dedicated project | **live** | off, permanently |

The rule that matters: **development and production payment credentials never
appear in the same place.** A sandbox key sitting next to a live key is a
mis-selected environment variable away from charging a real customer, or from
silently failing to.

`AppConfig` enforces the other half — `DEMO_MODE` is ignored in a production
build regardless of what the environment file says, so demo tooling cannot be
switched on in front of real customers by a configuration mistake.

## Backend

### Link and push

```bash
supabase link --project-ref <project-ref>
supabase db push
```

`db push` applies pending migrations. It does not run `seed.sql` — seed data
belongs only in development, and the seed itself refuses to run against a
database holding non-`@readytech.test` accounts.

Review what will be applied before you apply it:

```bash
supabase db diff --linked
```

### Migration discipline

Migrations are forward-only. A schema change is a new timestamped file, never an
edit to one already applied, because an edited migration has already run
everywhere else.

Two migrations exist purely because of this rule, and they are worth reading as
examples rather than tidying away:

- `20260101001700_service_catalogue.sql` — the service categories belonged in
  `20260101000300` beside `pricing_config`, but that had already been applied.
- `20260101001800_grants_hardening.sql` — supersedes the grants in
  `20260101001600` rather than correcting them in place.

Both would be a single edit in a pre-deployment repository. Once a migration has
run anywhere, the correction is a new file.

### Reference data vs seed data

The distinction decides which environments get what, so it is worth being
deliberate:

**Reference data** is anything the product cannot function without — the service
catalogue, the pricing table, the state-machine transition table. It ships in
migrations and therefore reaches every environment.

**Seed data** is demonstration material: accounts, devices, sample jobs. It
lives in `seed.sql`, runs only on `db reset`, and refuses to execute against a
database holding any non-`@readytech.test` account.

Getting this wrong is quiet rather than loud. The categories were originally in
`seed.sql`, which meant a freshly deployed project had an empty catalogue — no
error anywhere, but a customer could not file a request at all, because both
`estimate_service_cost()` and `rank_technicians()` key off a category.

The one to be careful with is the state machine. `service_status_transitions` is
data, so changing it is an `insert`/`delete` in a migration, and the matching
change to `ServiceStatus` in Dart must ship in the same release. The Dart copy
only hides buttons — if the two disagree the database wins, and users see a
confusing "cannot move" error.

### Edge Functions

```bash
supabase functions deploy calculate-matching
supabase functions deploy verify-payment --no-verify-jwt
```

`verify-payment` is the ToyyibPay webhook. It is called by ToyyibPay, not by a
signed-in user, so it cannot require a JWT — which means it must verify the
payment by calling ToyyibPay back rather than trusting the callback body. That
is the entire reason the function exists.

Every other function keeps JWT verification on.

Secrets, per environment:

```bash
supabase secrets set \
  TOYYIBPAY_BASE_URL=https://toyyibpay.com \
  TOYYIBPAY_SECRET_KEY=... \
  TOYYIBPAY_CATEGORY_CODE=... \
  GOOGLE_MAPS_API_KEY_SERVER=... \
  ALLOWED_ORIGINS=https://admin.readytech.example
```

`ALLOWED_ORIGINS` is not optional and must not be `*`. These functions act with
the service role.

### Auth configuration

In the Supabase dashboard, per project:

- **Site URL**: `readytech://auth-callback`
- **Redirect URLs**: the same, plus the admin console origin
- **Email confirmations**: on. The app's whole verification flow depends on it.
- **SMTP**: configure a real provider for staging and production. The built-in
  service is rate-limited and not for production use.

## Android

### Signing

```bash
keytool -genkey -v -keystore ~/readytech-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias readytech
```

Create `app/android/key.properties` — gitignored, and it must stay that way:

```properties
storePassword=...
keyPassword=...
keyAlias=readytech
storeFile=/absolute/path/to/readytech-release.jks
```

Losing this keystore means you can never update the app under the same listing.
Back it up somewhere that is not this repository.

### Build

```bash
cd app
flutter build appbundle --release \
  --dart-define-from-file=env/production.json
```

Output: `build/app/outputs/bundle/release/app-release.aab`

For a device install or a QA drop:

```bash
flutter build apk --release --split-per-abi \
  --dart-define-from-file=env/production.json
```

Before the first release, restrict the Android Maps key to the release SHA-1 as
well as the debug one, or maps will render blank in production.

## iOS

```bash
cd app/ios && pod install && cd ..
flutter build ipa --release --dart-define-from-file=env/production.json
```

Then upload `build/ios/ipa/*.ipa` through Xcode Organizer or Transporter.

Location permission strings must be present in `ios/Runner/Info.plist` before
Phase 5, and they have to explain *why*:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>ReadyTech uses your location to find technicians near you and to show
you where your technician is.</string>
<key>NSCameraUsageDescription</key>
<string>ReadyTech uses the camera to photograph your device before and after
the repair, so there is a record of its condition.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>ReadyTech lets you attach photos of the problem to your service
request.</string>
```

App Review rejects vague permission strings, and a user faced with an
unexplained location prompt denies it.

## Admin console

Phase 9. Deploys to Vercel:

```bash
cd admin
vercel --prod
```

Environment variables: `NEXT_PUBLIC_SUPABASE_URL` and
`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` are client-safe. The service-role key, if
the console needs one, goes in a server-only variable and is used exclusively in
server components and route handlers — never in anything prefixed
`NEXT_PUBLIC_`.

## Release checklist

Before a production build:

- [ ] `dart format --set-exit-if-changed lib test` clean
- [ ] `flutter analyze` clean
- [ ] `flutter test` green
- [ ] Migrations applied to production and reviewed with `db diff --linked`
- [ ] Edge Function secrets set on the production project, with **live**
      ToyyibPay credentials
- [ ] `env/production.json` points at the production Supabase project
- [ ] `DEMO_MODE` false
- [ ] Maps keys restricted to the release signing certificate and bundle id
- [ ] SMTP configured; a real confirmation email received end to end
- [ ] Version and build number incremented in `pubspec.yaml`
- [ ] A full lifecycle run through on staging: request → match → accept → arrive
      → diagnose → quote → approve → repair → complete → pay → warranty →
      review

The last one is not optional. The lifecycle is the product; a release that has
not been walked end to end has not been tested.

## Rollback

**App.** Halt the staged rollout in Play Console or App Store Connect and
promote the previous build. Mobile rollback is slow, which is why staging exists.

**Backend.** Migrations are forward-only: write a new migration that reverses
the change. Do not edit or delete an applied one.

**Edge Functions.** `supabase functions deploy <name>` from the previous commit.
This is the fastest lever you have — prefer putting risky logic in a function
over putting it in the app.
