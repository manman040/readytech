# ReadyTech mobile app

Flutter application for customers and technicians.

See the [repository README](../README.md) for an overview,
[docs/SETUP.md](../docs/SETUP.md) to get it running, and
[docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) for how it is put together.

```bash
flutter pub get
flutter run --dart-define-from-file=env/development.json
```

`--dart-define-from-file` is required. Without it the app starts on a
"not configured" screen naming the missing values. See [env/README.md](env/README.md).
