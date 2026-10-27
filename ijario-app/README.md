# Ijario — Flutter app

A rental marketplace app for Uzbekistan, in Uzbek. Browse without an account,
compare prices, message owners, book viewings, post your own listing.
Runs on Android, iOS, web and desktop from one codebase.

Design system and the reasoning behind it: [`../docs/DESIGN.md`](../docs/DESIGN.md).

## Run

```bash
flutter pub get
flutter analyze && flutter test
flutter run -d chrome                         # or any device
```

The backend URL is `http://localhost:8000` by default. Override at build time:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000          # Android emulator
flutter build web --release --dart-define=API_BASE_URL=https://your-api.example.com
```

Start the backend from `../ijario-backend` (see its README) and run
`python -m app.seed` for demo accounts (`demo.owner@ijario.uz` / `demo12345`).

## Structure

```
lib/
├── theme/        tokens.dart (the 5 palette colours, radii, motion), app_theme.dart (type + ThemeData)
├── models/       Property, Viewing, FilterCriteria, …
├── services/     ApiClient, AuthStore (persisted session), ChatStore (auto-reconnect), SettingsStore
├── data/         PropertyStore, ViewingStore
├── utils/        Uzbek formatters, validators, phone input, districts & amenities
├── widgets/      aurora, glass, logo mark, cards, buttons, sheets…
└── screens/      auth, home, property, saved, chat, profile, viewings, admin
assets/fonts/     Cormorant Garamond Italic + Manrope (OFL licensed, bundled: no runtime downloads)
```

## Features

Browse as a guest · filters (price, rooms, area, renovation, amenities, owner-only,
metro, utilities) with a live result count · price insight · viewing requests with
owner confirmation · live chat with quick replies · call / Telegram buttons ·
mark a listing as rented · views and saves per listing · report a listing ·
light / dark / system theme · stays signed in · admin stats.

## Release notes for Android

`INTERNET` permission is now declared in the main manifest (the 1.0 project only
had it for debug builds, so a release APK could not reach the server). The
application id is `uz.ijario.app`; change it if you publish under your own domain.
