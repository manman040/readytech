# Build environments

Compile-time configuration for the Flutter app. Copy the example you need and
drop the `.example` suffix:

```bash
cp development.json.example development.json
```

Then run with it:

```bash
flutter run --dart-define-from-file=env/development.json
```

Only the three `.example` files are tracked. The real `.json` files are
gitignored.

In VS Code, `app/.vscode/launch.json` already carries the flag - pick
**ReadyTech (local)** or **ReadyTech (staging)** and press Run. In Android
Studio, put `--dart-define-from-file=env/development.json` in
Run → Edit Configurations → Additional run args.

## `10.0.2.2`, not `127.0.0.1`

`development.json` points at `http://10.0.2.2:54321`, which looks wrong and is
not.

Inside an Android emulator, `127.0.0.1` is the emulator itself. The machine it
runs on is `10.0.2.2`. Pointing at loopback gives a connection failure that
looks like the local Supabase stack is down while it is running perfectly.

An iOS simulator shares the host's network, so `127.0.0.1` works there. Keep a
second file if you develop against both.

Local Supabase also serves plain HTTP, and Android has refused cleartext traffic
by default since Android 9. `android/app/src/debug/` carries a network security
config permitting it for `10.0.2.2` and localhost only, merged into **debug
builds alone**. A release build still refuses cleartext outright, and even in
debug the hosted project must use HTTPS.

## Do not put real values in `.env.example`

It is a template for server-side tooling, it is **committed to git**, and the
app never reads it. Real values placed there get published on the next push.

The app reads `app/env/<flavor>.json` at **build** time. That is why launching
without `--dart-define-from-file` shows the "not configured" screen regardless
of what any `.env` file contains.

## Why not a `.env` asset?

`flutter_dotenv` and similar packages bundle the file as an application asset,
which means it is readable by anyone who unzips the APK - and it is loaded at
runtime, so a missing value becomes a crash on a user's phone rather than a
build failure on yours. `--dart-define-from-file` bakes the values in as
compile-time constants instead, and `AppConfig.validate()` fails fast at startup
if one is absent.

Nothing secret goes in these files. The publishable key is meant for clients and
is protected by Row Level Security; the maps key must be restricted to the app's
package name and bundle id in the Google Cloud console. Service-role and payment
credentials live only in Edge Function secrets - see `.env.example` at the
repository root.
