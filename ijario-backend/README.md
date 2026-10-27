# Ijario — Backend

FastAPI backend for **Ijario**, a rental marketplace for Uzbekistan: JWT auth,
listings with search/filters, price insight, viewing requests, reports,
photo uploads, bookmarks and real-time chat. Dockerized and covered by an
automated test suite (59 tests).

> Free-tier hosts sleep after inactivity: the first request after a while can
> take 10–50 s. The app pings the server on launch to wake it early.

## What's in 2.0

- **Listings built for Uzbekistan** — city + district (Tashkent's 12 tumans),
  optional metro station, price in **so'm or USD**, **oylik / kunlik**, deposit,
  utilities included, owner vs. agent (`Egasi` / `Rieltor`), rented status.
- **Price insight** — `GET /properties/{id}` compares a monthly price with the
  median of similar active listings (same city, currency, rooms; district first)
  and returns `arzon / bozor_narxida / qimmat`. With too little data it returns
  `null` — it never guesses.
- **Viewing requests** — renter proposes a time, owner confirms or declines,
  both get a chat message. `POST /viewings`, `GET /viewings/mine`, `PATCH /viewings/{id}`.
- **Reports** — `POST /properties/{id}/report`; admins read `GET /admin/reports`.
- **Listing lifecycle** — owners mark a listing `band` (rented): it leaves search
  but stays in `GET /properties/mine`. Owners also see `views` and `saves_count`.
- **Mixed currencies done right** — filters and sorting compare in so'm using
  `USD_TO_UZS`; daily rates sort as ~30 days.
- **Privacy** — owner phone/Telegram are only sent to signed-in users.
- **Auto-migration** — `app/migrate.py` adds the new columns to an existing
  database on startup, so a deployed 1.0 database (e.g. Neon) keeps working.
- **Demo data** — `python -m app.seed` (3 accounts, 10 listings with photos; `--remove` deletes them and their photo files). Photo credits: `backend/app/seed_assets/CREDITS.md`.

### Bugs fixed from 1.0

| Bug | Effect | Fix |
|---|---|---|
| `is_admin` was never returned in user responses | The app could never show admin features | Serialised everywhere |
| Timestamps had no timezone marker | Clients showed times shifted by the UTC offset (5 h in Uzbekistan) | All datetimes are sent as UTC with `Z` |
| Amenity filter ran after pagination | Wrong `total`, missing results | Filtered before paginating |
| Changing email to an existing one | HTTP 500 | Clear 400 message |
| Email login was case-sensitive | Phone keyboards capitalise → "wrong password" | Case-insensitive |
| Tokens lasted 24 h | Daily sign-ins | 30 days |

## Run it

```bash
docker compose up --build
docker compose exec api python -m app.seed            # optional demo data
docker compose exec api python -m app.seed --remove   # delete the demo data again
# Optional: copy backend/.env.example to backend/.env to change settings (SECRET_KEY, USD_TO_UZS, ...)
```

- API: http://localhost:8000 · docs: http://localhost:8000/docs
- Adminer: http://localhost:8080 (server `db`, user `ijario`, password `ijario_secret`, db `ijario`)

Without Docker:

```bash
cd backend
pip install -r requirements-dev.txt
DATABASE_URL=sqlite:///./dev.db uvicorn app.main:app --reload
```

### Troubleshooting

**The `api` container keeps restarting.** Look at why:

```bash
docker compose logs api --tail 40
```

The usual cause is a *stale database volume*: Postgres only reads `POSTGRES_USER` /
`POSTGRES_PASSWORD` the first time a volume is created, so a volume left over from an
earlier run (or an older project) rejects the new credentials. Throw it away and start clean
(this deletes the local database, which is fine for development):

```bash
docker compose down -v
docker compose up --build
```

Other quick checks: port 8000 or 5433 already in use on your machine; `docker compose exec` only
works while the container is *running* (wait for it to stop restarting first).

## Tests

```bash
cd backend && pip install -r requirements-dev.txt && pytest -q
```

Runs on a disposable SQLite database. Covers auth, listings, filters, price
insight, viewings, reports, privacy, chat, admin and the migration of an old
database.

## API overview

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register`, `/auth/login` | JWT. Phone accepts any Uzbek format → `+998…` |
| GET | `/auth/me` | |
| PUT | `/users/me` | name, email, phone, telegram, password (empty phone/telegram clears) |
| POST | `/users/me/avatar` | multipart |
| GET | `/properties` | `q, city, location, min_price, max_price` (so'm-equivalent), `price_unit, min_bedrooms, min_area, max_area, renovation, amenities, student_only, owner_only, near_metro, utilities_included, include_inactive, sort=new\|cheap\|expensive\|area` |
| GET | `/properties/mine` | all of my listings incl. rented |
| GET | `/properties/{id}` | + `price_insight`, counts a view |
| POST/PUT/DELETE | `/properties[/{id}]` | owner only; `status: faol\|band` |
| POST/DELETE | `/properties/{id}/images[/{image_id}]` | |
| POST | `/properties/{id}/save` | toggle bookmark |
| POST | `/properties/{id}/report` | `aldamchi, narx_notogri, allaqachon_band, boshqa` |
| POST / GET / PATCH | `/viewings`, `/viewings/mine`, `/viewings/{id}` | `kutilmoqda → tasdiqlandi / rad_etildi / bekor_qilindi` |
| GET | `/messages/conversations`, `/messages/with/{id}` | |
| POST | `/messages` | REST fallback |
| WS | `/messages/ws?token=…` | live chat |
| GET | `/admin/stats`, `/admin/users`, `/admin/reports` · DELETE `/admin/users/{id}`, `/admin/properties/{id}` | admin only |
| GET | `/meta` | `usd_to_uzs`, `api_version` |

A ready-to-import Postman collection is in `postman/`.

## Environment

| Variable | Notes |
|---|---|
| `DATABASE_URL` | Postgres (or SQLite for dev) |
| `SECRET_KEY` | JWT signing key — **change it** |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | default 43200 (30 days) |
| `USD_TO_UZS` | approximate rate for comparing currencies (default 12000) |
| `UPLOAD_DIR`, `BASE_URL` | local upload storage |
| `R2_*` | optional Cloudflare R2 storage (needed on hosts without a persistent disk) |

## Notes

- Schema upgrades: `ensure_columns` only *adds* columns. When changes get more
  complex, move to Alembic.
- CORS is open (`*`) — restrict it to your app's origin in production.
