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
