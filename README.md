# ဘတ်ဈေး · Currency app

## Live app and daily administration

- Public app: https://sharedbyatt-maker.github.io/thai-helper-app/
- Daily rates administration: https://bahtzay-rates.muddyhinny2048.chatgpt.site/admin/index.html
- Public rates API: https://bahtzay-rates.muddyhinny2048.chatgpt.site/api/v2/rates

The hosted backend uses ChatGPT Sites with a durable Cloudflare D1 database. No paid Render service is required or provisioned. Sites account terms and availability apply; this is not a promise of unlimited hosting or permanent pricing.

Sign into the dashboard with the ChatGPT account that owns this Site. The initial owner is checked against the trusted Sites access record, then its Site-specific identity is pinned in the database. Other signed-in accounts cannot edit rates. No new password, API key, or activation code is needed.

Enter separate THB→MMK and MMK→THB prices in baht per 100,000 MMK, confirm that you checked each updated price, then **Save Draft → Preview → Publish**. Drafts stay private. The app refreshes about once a minute. No invented live rates are supplied: the owner must publish the first real daily sheet.

`hosted_backend/` retains the deployed backend source, migrations, tests and Sites build integration. Its native Site source repository is synchronized separately by the Sites workflow. Personal transaction records remain browser-local, not in the shared backend.

The GitHub Pages workflow uses this hosted API by default. Set the optional repository Actions variable `RATES_API` to a different origin when migrating. The Flutter client itself retains same-origin API behavior when built without that define, suitable for the optional Python/Docker deployment below.

## Simple daily workflow

The public calculator starts with amount and rate only. Comparison and target-payout options are collapsed. The public app has no source-details drawer or editable deduction inputs. Legacy nonzero published deductions remain a read-only notice and stay included in results; editing a rate clears legacy deductions so manual prices never silently retain them. The calculator uses a compact centered layout, large numeric entry and highlighted results. The rate board preserves a real chart marker or an explicit empty chart frame when history is limited.

The hosted admin form has one independent per-lakh input for each direction, faded examples, an equivalent-rate explanation, a check confirmation and a daily recheck shortcut. Source/provider and fee inputs are removed; internal generic provenance remains for compatibility. Existing quote IDs survive daily edits and re-adding a direction. Time fields are optional details. Unchanged legacy deductions are preserved transparently; typing a new price clears them. Example numbers are never saved as actual prices.

## User interface and rate trend

The public board opens with the 7-day chart, with Today / 7-day / 30-day choices, selectable observations, low/high summaries and independent directional price cards. `/api/v2/history` returns daily points and deduplicated timestamped observations from immutable publications. Today shows real intraday updates; longer periods use the last observation per Bangkok day. The chart follows a stable published quote ID, direction and payout method across optional display/source-name changes; each observation retains its own source name for inspection. It never fills missing dates or invents rates. A single observation is a visible point and value; zero observations retain a labeled chart frame. Both directions display baht per 100,000 MMK consistently, using their separately entered rates. Calculator entry uses the selected published rate when available and preserves personal comparison entries and budget on refresh. Cache/storage failure does not prevent online rate reads. Displayed chart rates exclude fees. The optional standalone Python backend does not currently expose the history endpoint; its calculator and daily sheet remain usable.

## Features

Currency-only tools for Myanmar users: owner-published directional quotes, personal quote comparison, timestamped price sharing, opt-in Telegram price alerts, and device-local exchange records with backup import/export. Thai language features and simulated provider rankings are not part of the active app.

## What the owner does each day

1. Open `/admin` and sign in.
2. Add or edit **ဘတ်ပေး → ကျပ်ယူ** and **ကျပ်ပေး → ဘတ်ယူ** separately. Neither direction is inferred from the other.
3. Enter baht per 100,000 MMK. Updating the price sets the observation time to now and freshness to 24 hours. Expand time details only when you need to record a different check time.
4. Confirm the updated price was checked, save Draft, then Preview. The daily recheck shortcut can confirm an unchanged price without typing it again.
5. Publish. Public clients refresh automatically once per minute and can pull to refresh. Unpublished drafts remain private.
6. To correct a mistake, restore an earlier version to Draft, review its rate/expiry, then publish a new version. Restoring alone does not change public data.

Empty publishing is supported to withdraw all quotes. Expired or future quotes are visible with a warning but cannot be selected for calculation. A successful source check is not a guarantee about an exchanger or payment completion.

## Optional standalone Python deployment

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

## GitHub Pages deployment

The public Flutter build stays on GitHub Pages; the daily-rate API and admin run on Sites. `Publish currency web` builds with the hosted API origin by default. An optional `RATES_API` Actions variable can override it. Missing network access falls back to a cached sheet or empty bundled sheet, while personal calculators keep working. No market quotes are invented.

The previous scheduled estimated-provider updater is removed. Legacy data and archived phrasebook files are not read by this UI or the publishing API.

## Calculator contract

- Amounts accept Myanmar, Thai and English digits, commas and up to two decimal places.
- Quotes store MMK per THB as integer millionths. Both paying and receiving amounts use 1/100 minor units.
- **Input is total spending, including fees.** `fee = flat + ceil(total × percentage)`; payout converts the remaining amount and rounds down to a minor unit.
- Target-payout calculation returns the smallest total budget that meets the target using the chosen flat/percentage fee. It does not use the previous global search across stepped provider fees.
- The calculator compares at most three quotes in the same direction. A comparison assumes the user has checked matching payout methods and conditions.
- The legacy rate parser remains covered by unit tests; its calculator paste UI has been removed. Parser examples: `1 THB = 125 MMK`, `၁ ဘတ် = ၁၂၅ ကျပ်`, `၁ သိန်း = ၈၀၀ ဘတ်`. These numbers are **format examples, not real quotes**. Ambiguous/multiple different rates are rejected. Screenshot OCR is not included.
- Source-selected quotes lose their checked-source provenance when the user edits them. Expired source quotes cannot be calculated as current quotes.

## Personal records

No customer login is needed. Rate snapshots, amounts and optional notes are stored using SharedPreferences on the current device/browser; no personal records are sent to the publishing backend. Users can mark a saved calculation as completed, choose the actual completion date, delete records, download JSON, and preview a non-destructive JSON import. Completion is user-reported, not independently verified.

Monthly summaries keep THB→MMK and MMK→THB totals separate and include only completed records. They use the actual completion date, falling back to the save date for older records without a completion date. Limits: 500 records; browser storage can be cleared or lost; no cross-device sync. Export important records. Corrupt stored data is not silently replaced.

## Security and operational limits

The optional Python backend has hashed-password login, random server-side sessions (8 hours), HttpOnly/Secure/SameSite cookies, CSRF tokens, origin checks, database-backed login throttling, draft version conflict detection, immutable published revisions and safe DOM rendering. Changing the password hash invalidates prior sessions. Source URLs are limited to HTTP(S).

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

### Telegram မှ နှုန်းတင်ခြင်း (hosted backend)

Admin → **စာပို့ပြီး နှုန်းတင်မယ်** → Settings:

1. Telegram [@BotFather](https://t.me/BotFather) မှာ `/newbot` ဖြင့် ကိုယ်ပိုင် bot ဖန်တီးပါ။
2. ရသော token ကို Admin ရဲ့ password အကွက်ထဲ ထည့်ပြီး ပြမည့်အမည်ကို လိုမှဖြည့်ကာ **Bot ချိတ်မယ်** နှိပ်ပါ။ Token ကို GitHub သို့မဟုတ် chat ထဲ မတင်ပါနှင့်။
3. **ငါ့ Telegram ချိတ်မယ်** နှိပ်၊ ပေါ်လာသော link ဖြင့် Telegram မှာ Start နှိပ်ပါ။ Link သက်တမ်း ၁၀ မိနစ်ဖြစ်ပြီး တစ်ခါသာသုံးနိုင်သည်။ ချိတ်ပြီးသော Telegram account တစ်ခုတည်းက နှုန်းတင်နိုင်သည်။

Daily: Channel ရွေးရန်မလိုပါ။ ဘယ် channel ကစာမဆို ကူးပို့နိုင်သည်။ `ကျပ်ပေး ဘတ်ယူ 726` သို့မဟုတ် `726` ပို့ပါ။ **ကျပ် ၁ သိန်း = ဘတ် 726** ဖြစ်သည်။ နံပါတ်တစ်ခုတည်းပို့လျှင် Admin တွင် သတ်မှတ်ထားသော ဦးတည်ချက်ကို သုံးသည်။ Viber စာအပြည့်တွင် နှုန်းများပါလျှင် ၁၀ မိနစ်သက်တမ်းရှိ ခလုတ်များမှ တစ်ခုသာရွေးနိုင်သည်။ တစ်ဘက်နှုန်းရလျှင် အခြားဘက်ပါ ထည့်ဦးမလား မေးပြီး ထည့်မယ်ဆို သီးခြားနှုန်းကို ဆက်ပို့နိုင်သည်။ မထည့်သေးဆို ယခင်အခြားဘက်နှုန်းကို မူလစစ်ချိန်အတိုင်း ဆက်ထားပြီး မရှိလျှင် အလွတ်ထားသည်။ နှစ်ဘက်နှုန်းကို အလိုအလျောက် ပြန်မတွက်ပါ။ နမူနာအချက်အလက်ကို အရင်ပြပြီး **မှန်တယ်၊ Public တင်မယ်** နှိပ်မှသာ တင်သည်။ **မတင်တော့ဘူး** သို့မဟုတ် `/cancel` ဖြင့် ရပ်နိုင်သည်။ အတည်မပြုမချင်း public rates / history / Admin draft ကို မပြောင်းပါ။ စာအသစ်ပို့လျှင် ခလုတ်ဟောင်းကို ပိတ်ပြီး Admin မှ Public နှုန်းပြောင်းထားလျှင် နမူနာအသစ် ပြန်စစ်ရသည်။ ငွေပမာဏအဆင့်များ၊ fee နှင့် OCR မပါပါ။ `/status` ဖြင့် နှုန်းကြည့်၊ `/undo` ဖြင့် နောက်ဆုံး Telegram တင်ချက်ကို ပြန်ဖျက်နိုင်သည်။

နှုန်းကို public rates နှင့် trend history သို့ တင်သည်။ ၂၄ နာရီကျော်လျှင် ပြန်မစစ်ရသေးသောနှုန်းဟု ဆက်ပြပြီး လက်ရှိနှုန်းအဖြစ် မတွက်ပေးပါ။ နှုန်းမှတ်တမ်းကို မဖျက်ပါ။ ရှိပြီးသား ဦးတည်ချက်တူနှုန်းကို အစားထိုးပြီး သီးခြား ပြောင်းပြန်ဦးတည်ချက်ကို မခန့်မှန်းပါ။ Draft သည် published နှင့် တူနေမှ sync လုပ်ပြီး မတင်ရသေးသော Draft ကို ထိန်းထားသည်။ Telegram တင်ပြီးနောက် Admin ကို Reload လုပ်ပါ။

Hosting secret `TELEGRAM_CONFIG_KEY` သည် random 32-byte hexadecimal key ဖြစ်ရမည်။ Native Sites environment secret အဖြစ်သာ သိမ်းပြီး deploy လုပ်ရသည်။ Bot token/webhook secret ကို AES-GCM ဖြင့် encrypt လုပ်ကာ D1 တွင် သိမ်းသည်။ Key ကို အလိုအလျောက် မပြောင်းပါနှင့်။ Token ကို UI/API က ပြန်မပေးပါ။ Webhook သည် Telegram secret header၊ paired sender၊ private chat နှင့် durable duplicate receipt ကို စစ်သည်။ အသစ်ထည့်ထားသော Drizzle migrations ကို deploy ဖြင့် apply လုပ်ရသည်။ Local Python backend တွင် Telegram integration မပါပါ။

## Confirmed six-day history replacement

The owner approved replacing the previous published price history and draft with six daily observations on 2026-10-17. Values below are baht per 100,000 MMK; MMK→THB uses the first (3-lakh minimum) price from the supplied screenshots. Only the last visible update on each confirmed date is included.

| Bangkok date | Source time | MMK→THB | THB→MMK |
| --- | --- | ---: | ---: |
| 2026-10-12 | 19:28 | 738 | 760 |
| 2026-10-13 | 16:19 | 733 | 755 |
| 2026-10-14 | 19:14 | 720 | 745 |
| 2026-10-15 | 12:00 | 706 | 740 |
| 2026-10-16 | 17:12 | 724 | 748 |
| 2026-10-17 | 12:31 | 724 | 748 |

`confirmed-history.mjs` contains the fixed dataset and a one-use operation protected by a high-entropy capability hash. No plaintext capability is stored in source. The operation checks the current revision and draft version, archives prior revisions and the draft in `history_replacements`, replaces prices in one atomic D1 batch, increments the draft version and invalidates prior pending Telegram confirmations. Account settings, bot configuration and receipts are retained. The receipt prevents any later retry from erasing new owner publications. Actual source observation times and 24-hour freshness are retained; publication timestamps record the import time. Schema migrations contain only the added archive/receipt table.

Phone layouts use fully wrapping, equal-height direction cards without chip avatar/fade constraints. The mobile trend card uses a 108px plot, compact periods/summary and fewer repeated labels; desktop retains the detailed 158px chart. Responsive tests load the real Myanmar fonts and check 320–430px widths, larger accessibility text, glyph selection bounds, six real points and card height.


## Daily-use tools and subscriber alerts

- Home retains a separate personal amount for each direction on this browser. It shows the payout and difference against the most recent actual earlier Bangkok day; a missing yesterday is labeled by its actual date. Freshness checks also apply here. Prices and reverse prices are never invented.
- Planned dates are local notes shown when the app is opened, not background calendar notifications. Home Screen installation is offered after repeat visits. It uses the browser install prompt when available and otherwise gives iPhone/Android instructions.
- The daily share card contains public prices, original observation times, stale labels and the app URL. It excludes private amounts, notes, records, and source names. A PNG can be shared or downloaded when native file sharing is unavailable.
- JSON import validates the whole backup before offering a count preview. It merges by record ID, skips duplicates without replacing existing records, and enforces the 500-record limit. Export/import and PNG download are provided for the deployed web app.
- The daily Admin editor accepts baht per 100,000 MMK with independent prices and stable per-direction feed IDs. Source/provider and fee inputs have been removed. Untouched legacy deductions remain honestly preserved; entering a new price explicitly clears them. Unchanged expired opposite quotes may be carried forward with their real observation time alongside a fresh direction.
- A user chooses the bell on Home, selects daily-price news or a target, opens Telegram, and presses Start. News uses `news_thb_mmk` / `news_mmk_thb`; one-shot targets use `watch_<direction>_<hundredths-of-baht-per-lakh>`. THB→MMK targets mean at or below; MMK→THB means at or above. The bot stores only the Telegram chat ID, direction, mode and target needed for delivery. `/stop` disables sends; resubscribing invalidates older queued messages. Public subscribers never obtain owner publishing privileges.
- Notifications evaluate only confirmed, fresh publications. Same-day unchanged rates and carried opposite rates are suppressed. A new day's confirmation may send the same price again. Target alerts stop after a successful send. The queue has bounded batches, leases, Telegram backoff, and expiry checks. Publishing, public rate reads and Admin insight refresh resume pending work through the Worker request's background lifetime. There is no independent minute-by-minute cron: delivery can be delayed during Telegram/network failure until another publication/read/insight refresh. External delivery is at least once; a rare ambiguous network timeout can result in a repeated message.
- Admin insight counts show active subscriptions and queued/delivered messages. Personal record amounts and browser usage are not sent to the publishing backend. Published data and existing owner/bot settings are not changed by these additive schema migrations.
