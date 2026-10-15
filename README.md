# ဘတ်ဈေး — THB ↔ MMK

Currency-only tools for Myanmar users: owner-published directional quotes, personal quote comparison, pasted chat rates, and device-local exchange records. Thai language features and simulated provider rankings are not part of the active app.

## What the owner does each day

1. Open `/admin` and sign in.
2. Add or edit **ဘတ်ပေး → ကျပ်ယူ** and **ကျပ်ပေး → ဘတ်ယူ** separately. Neither direction is inferred from the other.
3. Enter a rate as MMK per THB or THB per 100,000 MMK, plus the fee in the paying currency, source, payout method, observed time and expiry (up to seven days).
4. Check the source confirmation, save Draft, then Preview.
5. Publish. Public clients refresh automatically once per minute and can pull to refresh. Unpublished drafts remain private.
6. To correct a mistake, restore an earlier version to Draft, review its rate/expiry, then publish a new version. Restoring alone does not change public data.

Empty publishing is supported to withdraw all quotes. Expired or future quotes are visible with a warning but cannot be selected for calculation. A successful source check is not a guarantee about an exchanger or payment completion.

## Running the complete app

Use Flutter **3.47.7**, Dart **3.13**, Python **3.12**. Font files are fetched once from a pinned Google Fonts commit and SHA-256 verified at build time; the built app bundles them for offline use. The same server can serve the Flutter build, public API and admin dashboard; this avoids cross-site login problems.

```bash
python scripts/fetch_fonts.py
cd flutter_app
flutter pub get
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
cd ..
python -m venv .venv
.venv/bin/pip install -r backend/requirements.txt
.venv/bin/python backend/set_password.py
```

The password helper prompts without echoing and prints a password hash. Set that output as the server's `ADMIN_PASSWORD_HASH` environment variable. There is no default password. Do not commit credentials.

For local HTTP development only, set `COOKIE_SECURE=false`. Run:

```bash
.venv/bin/python backend/app.py
```

Then open `http://127.0.0.1:5000` and `http://127.0.0.1:5000/admin`.

For production use HTTPS, `COOKIE_SECURE=true`, and a **persistent writable disk** for `EXCHANGE_DATABASE`. The default path is `backend/instance/exchange.sqlite3`. A temporary filesystem loses rate versions and sessions when the host restarts. The database uses WAL and transactions; use SQLite's backup API or stop the service for a consistent backup, rather than copying only the main database file while it is running.

```bash
cd backend
gunicorn --bind 0.0.0.0:8000 --workers 2 app:app
```

If the service sits behind exactly one trusted HTTPS reverse proxy, set `TRUST_PROXY=true` so the admin same-origin check sees HTTPS. Do not enable that setting on a server directly reachable around the proxy. Proxy-forwarded IPs are not trusted for authentication throttling.

`Dockerfile` builds the web app and serves everything on port 8000. `render.yaml` is an optional Render blueprint using a **paid** persistent disk service; review hosting costs before deployment. This repository change does not create a hosting account or deploy a paid service. The container user (UID 10001) must be able to write to `/data`.

## Keeping GitHub Pages

GitHub Pages can serve the public Flutter UI, but cannot run the admin/database service. Deploy the backend separately and set repository **Actions variable** `RATES_API` to its HTTPS origin, without a trailing slash. Run **Publish currency web**. `/admin` lives at that backend origin.

Without `RATES_API`, the UI tries `/api/v2/rates` on its own origin. On GitHub Pages that endpoint is unavailable: the app uses a cached sheet or an empty bundled sheet and personal calculators continue to work. It never invents market quotes. For a live daily rate board, the backend must be configured and reachable.

The previous scheduled estimate updater has been removed from the deployment workflow. Legacy `rates.json`, `update_rates.py`, and archived phrasebook files are retained for historical reference and are not used by this currency UI or publishing API. They cannot overwrite the SQLite-published quote sheet.

## Calculator contract

- Amounts accept Myanmar, Thai and English digits, commas and up to two decimal places.
- Quotes store MMK per THB as integer millionths. Both paying and receiving amounts use 1/100 minor units.
- **Input is total spending, including fees.** `fee = flat + ceil(total × percentage)`; payout converts the remaining amount and rounds down to a minor unit.
- Target-payout calculation returns the smallest total budget that meets the target using the chosen flat/percentage fee. It does not use the previous global search across stepped provider fees.
- The calculator compares at most three quotes in the same direction. A comparison assumes the user has checked matching payout methods and conditions.
- Pasted text is parsed on the device, not sent to an AI service. Supported examples: `1 THB = 125 MMK`, `၁ ဘတ် = ၁၂၅ ကျပ်`, `၁ သိန်း = ၈၀၀ ဘတ်`. These numbers are **format examples, not real quotes**. Ambiguous/multiple different rates are rejected. The user must confirm the interpretation and separately enter direction/fees. Screenshot OCR is not included.
- Source-selected quotes lose their checked-source provenance when the user edits them. Expired source quotes cannot be calculated as current quotes.

## Personal records

No customer login is needed. Rate snapshots, amounts and optional notes are stored using SharedPreferences on the current device/browser; no personal records are sent to the publishing backend. Users can mark a saved calculation as completed, delete records, and export/share JSON. Completion is user-reported, not independently verified.

The monthly THB→MMK summary includes only records marked completed and groups them by the month the calculation was saved. Limits: 500 records; browser storage can be cleared or lost; no cross-device sync. Export important records. Corrupt stored data is not silently replaced.

## Security and operational limits

Admin has hashed-password login, random server-side sessions (8 hours), HttpOnly/Secure/SameSite cookies, CSRF tokens, origin checks, database-backed login throttling, draft version conflict detection, immutable published revisions and safe DOM rendering. Changing the password hash invalidates prior sessions. Source URLs are limited to HTTP(S).

There are no payment handling, public seller listings, referral click tracking, unprotected statistics or claimed exchanger trust badges. This is not an audited production financial system: owner source checks, hosting configuration, backups and fresh quotes remain required.

## Checks

```bash
python -m pip install -r backend/requirements.txt pytest
python -m pytest backend/tests -q
npm ci --ignore-scripts
node --check backend/admin/app.js
npm run test:admin
cd flutter_app
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

CI runs backend checks plus Flutter analysis, tests and web build for pull requests. Publishing is a separate workflow after merge/manual dispatch.
