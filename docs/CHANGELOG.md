# What changed: OsonIjara → Ijario 2.0

## Brand
- Renamed to **Ijario** everywhere: Dart package, Android/iOS/macOS/Windows/Linux ids and
  labels, web manifest, API title, Docker, tests, docs.
- New logo mark and app icons for every platform; palette from your colour card.
- Interface is fully in Uzbek.

## Depth, glass and colour pass
- Fixed: a faint square showed under the photo on listing cards (the placeholder artwork was
  painted taller than its canvas and was not clipped).
- Fixed: `CupertinoPageTransitionsBuilder` was used without its import (compile error).
- Layered look: glowing app backdrop, translucent raised cards with tinted shadows, lit
  gradient buttons/chips/bubbles, a floating nav bar with a glowing add button.
- 3-D: listing cards tilt in perspective with a moving glare. (An earlier build also floated glass spheres in the backgrounds; they looked wrong and were removed. The welcome screen now uses a real frosted-glass pane instead.)
- Pushed pages (my listings, viewings, chat, edit profile, admin) share the same backdrop.

## New features
| Feature | Why it earns its place |
|---|---|
| Browse without an account | Sign-in is asked for only when you save, chat, book or post |
| Stays signed in (30-day token) | Previously the session was lost on every restart |
| Currency: so'm / USD, oylik / kunlik, deposit, utilities | How rentals are actually quoted in Uzbekistan |
| City + the 12 districts of Tashkent, optional metro station | Location is the first filter people use |
| Owner vs. agent, "Faqat egasidan" filter | The commission-free search people ask for |
| **Price insight** | "12% cheaper than similar flats in this district", only when there is enough data |
| **Viewing requests** | Pick day and hour, owner confirms/declines, chat gets a message |
| Mark a listing as rented | Stale listings are the biggest trust problem in classifieds |
| Views and saves on my listings | Useful to a landlord, real counts |
| Report a listing + admin report list | Fake listings need a reporting path |
| Call and Telegram buttons | One tap to reach the owner |
| Quick-reply chips in an empty chat | Removes the blank-page problem |
| Chat auto-reconnect, unread badges, listing pinned in chat | Chat used to die silently if the socket dropped |
| Light / dark / system theme | Dark uses Obsidian from your palette |
| Demo data seeder, Postman collection | Fresh installs aren't empty |

## Removed (and why)
- Area ranges up to "600+ m²" and the bathrooms filter: meaningless for flats.
- Hard-coded location chips (a mix of a district, a city and a street): replaced by real city/district data.
- The "Yomon" (bad) renovation option: nobody advertises a flat as bad; replaced by "Ta'mir talab".
- The sign-in wall in front of the whole app.
- Owner phone numbers in public API responses: now sent only to signed-in users.

## Bugs fixed
- `is_admin` was never returned by the API, so the app could never show admin features.
- **Android release builds had no `INTERNET` permission** (only debug did), so a release APK could not reach the server.
- Timestamps had no timezone, so chat and dates were off by 5 hours.
- Amenity filter ran after pagination (wrong totals, missing results).
- Changing email to an existing one returned HTTP 500.
- Email login was case-sensitive (phone keyboards capitalise the first letter).
- The old `widget_test.dart` was the default Flutter counter test, which cannot pass against this app; replaced with real tests.

## Compatibility
- Existing databases keep working: new columns are added automatically on startup, and old renovation labels are mapped (`Ideal` → `Evro ta'mir`, `Yomon` → `Ta'mir talab`).
- `google_fonts` (runtime font download) is replaced by bundled, offline fonts.
- API changes are additive. The only behavioural changes: contact details are hidden from
  anonymous callers, and `GET /properties` hides listings marked `band` unless
  `include_inactive=true`.

## Verification status — please read
| Part | Status |
|---|---|
| Backend | 59 automated tests pass; also booted and exercised over real HTTP |
| Flutter app | **Not compiled here** (the Flutter SDK host is blocked in my environment). Verified: Dart syntax parses cleanly on every file; every import resolves; every project symbol is imported where used; no `const` misuse; APIs checked against Flutter 3.38 / Dart 3.11 (your lockfile's versions). Expect to run `flutter pub get`, `flutter analyze` and `flutter test` once; if the analyzer reports anything, it should be small. |
| Dart tests | Written, not executed here (expected values cross-checked independently) |
